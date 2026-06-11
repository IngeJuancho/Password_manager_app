package com.example.password_manager

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.service.autofill.*
import android.text.InputType
import android.util.Log
import android.view.View
import android.view.autofill.AutofillId
import android.view.inputmethod.InlineSuggestionsRequest
import android.widget.RemoteViews
import androidx.annotation.Keep
import androidx.annotation.RequiresApi
import androidx.autofill.inline.v1.InlineSuggestionUi
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import java.util.Locale

@RequiresApi(Build.VERSION_CODES.O)
class AutofillService : android.service.autofill.AutofillService() {

    companion object {
        private const val TAG = "🚀AutofillBrain"
        private const val MIN_SCORE_THRESHOLD = 30
    }

    // ==================== PUNTO DE ENTRADA PRINCIPAL ====================

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: android.os.CancellationSignal,
        callback: FillCallback
    ) {
        try {
            val context = request.fillContexts.lastOrNull() ?: run {
                callback.onSuccess(null)
                return
            }

            val structure = context.structure
            val packageName = structure.activityComponent.packageName
            Log.d(TAG, "onFillRequest para: $packageName")

            val fields = detectLoginFields(structure)

            if (fields.usernameIds.isEmpty() && fields.passwordIds.isEmpty()) {
                Log.d(TAG, "No se detectaron campos de login.")
                callback.onSuccess(null)
                return
            }

            Log.d(TAG, "Campos detectados → usuarios: ${fields.usernameIds.size}, contraseñas: ${fields.passwordIds.size}")

            val responseBuilder = FillResponse.Builder()
            configureSaveInfo(responseBuilder, fields)

            val repository = SecureRepository(this)
            val jsonString = repository.getVault()

            if (jsonString != null) {
                val passwordList = parsePasswords(jsonString).toMutableMap()
                val matches = findMatchingPasswords(passwordList, packageName)
                var vaultWasModified = false

                Log.d(TAG, "Credenciales coincidentes: ${matches.size}")

                if (matches.isNotEmpty()) {
                    val inlineRequest: InlineSuggestionsRequest? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                            request.inlineSuggestionsRequest
                        else null

                    matches.entries.forEachIndexed { index, (key, entry) ->
                        val uniqueRequestCode = (key + index).hashCode()
                        val dataset = buildAuthenticatedDataset(
                            entry = entry,
                            fields = fields,
                            targetPackage = packageName,
                            inlineRequest = inlineRequest,
                            uniqueRequestCode = uniqueRequestCode
                        )
                        responseBuilder.addDataset(dataset)

                        if (entry.packageId.isNullOrEmpty()) {
                            passwordList[key] = entry.copy(packageId = packageName)
                            vaultWasModified = true
                        }
                    }

                    if (vaultWasModified) saveVaultSilently(repository, passwordList)
                }
            }

            callback.onSuccess(responseBuilder.build())

        } catch (e: Exception) {
            Log.e(TAG, "Error crítico en onFillRequest", e)
            callback.onSuccess(null)
        }
    }

    // ==================== CONSTRUCCIÓN DEL DATASET ====================

    private fun buildAuthenticatedDataset(
        entry: PasswordEntry,
        fields: LoginFields,
        targetPackage: String,
        inlineRequest: InlineSuggestionsRequest?,
        uniqueRequestCode: Int
    ): Dataset {

        // A. Presentación del menú flotante
        val dropdownView = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_title, "🔐 ${entry.app}")
            setTextViewText(R.id.autofill_subtitle, entry.username ?: "Toca para desbloquear")
        }

        // B. PendingIntent hacia AuthenticationActivity
        val authIntent = Intent(this, AuthenticationActivity::class.java).apply {
            putExtra("app_name", entry.app)
            putExtra("username", entry.username)
            putExtra("password", entry.password)
            putExtra("target_package", targetPackage)
            putParcelableArrayListExtra("username_ids", ArrayList(fields.usernameIds))
            putParcelableArrayListExtra("password_ids", ArrayList(fields.passwordIds))
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else
            PendingIntent.FLAG_UPDATE_CURRENT

        val pendingIntent = PendingIntent.getActivity(
            this, uniqueRequestCode, authIntent, pendingFlags
        )

        // C. Presentación Inline (teclado)
        val inlinePresentation: InlinePresentation? = buildInlinePresentation(inlineRequest, entry)

        // D. Ensamblar Dataset
        // FIX #1: Dataset.Builder DEBE recibir la presentación dropdown desde el constructor.
        // Sin esto, en Android 8-10 el Dataset.build() lanza una excepción silenciosa.
        val datasetBuilder = Dataset.Builder(dropdownView)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && inlinePresentation != null) {
            datasetBuilder.setInlinePresentation(inlinePresentation)
        }

        datasetBuilder.setAuthentication(pendingIntent.intentSender)

        // FIX #2: Con setAuthentication() activo los valores DEBEN ser null.
        // Un valor no-nulo (como "••••••••") hace que Android asuma que el dataset
        // ya está listo y omite lanzar el PendingIntent de autenticación.
        val allIds = fields.usernameIds + fields.passwordIds
        for (id in allIds) {
            datasetBuilder.setValue(id, null, dropdownView)
        }

        return datasetBuilder.build()
    }

    private fun buildInlinePresentation(
        inlineRequest: InlineSuggestionsRequest?,
        entry: PasswordEntry
    ): InlinePresentation? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        if (inlineRequest == null) return null

        val specs = inlineRequest.inlinePresentationSpecs
        if (specs.isEmpty()) return null

        return try {
            // Intent fantasma: obliga al SO a usar el IntentSender de setAuthentication()
            val dummyIntent = PendingIntent.getActivity(
                this, 0, Intent(), PendingIntent.FLAG_IMMUTABLE
            )

            val content = InlineSuggestionUi
                .newContentBuilder(dummyIntent)
                .setTitle("🔐 ${entry.app}")
                .setSubtitle(entry.username ?: "Desbloquear")
                .setStartIcon(
                    android.graphics.drawable.Icon.createWithResource(this, R.mipmap.ic_launcher)
                )
                .build()

            InlinePresentation(content.slice, specs[0], false)
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo construir InlinePresentation: ${e.message}")
            null
        }
    }

    // ==================== DETECCIÓN HEURÍSTICA DE CAMPOS ====================

    private fun detectLoginFields(structure: AssistStructure): LoginFields {
        val allFields = mutableListOf<FieldInfo>()
        for (i in 0 until structure.windowNodeCount) {
            collectFields(structure.getWindowNodeAt(i).rootViewNode, allFields)
        }

        val scores = allFields.associateBy({ it.id }, { ScoredField(it.id) })

        for (field in allFields) {
            var uScore = 0
            var pScore = 0

            val inputType = field.inputType
            val isMultiline = (inputType and InputType.TYPE_TEXT_FLAG_IME_MULTI_LINE) != 0

            val isTextPassword =
                (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
            val isNumberPassword =
                (inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_NUMBER &&
                (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_NUMBER_VARIATION_PASSWORD
            if (isTextPassword || isNumberPassword) pScore += 60

            val isEmail =
                (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS
            if (isEmail) uScore += 40

            val hintsJoined = field.autofillHints?.joinToString(" ")?.lowercase() ?: ""
            if (hintsJoined.contains("username") || hintsJoined.contains("email")) uScore += 50
            if (hintsJoined.contains("current-password")) pScore += 50
            if (hintsJoined.contains("new-password")) pScore += 20
            if (hintsJoined == "password") pScore += 40

            val contextText =
                "${field.idEntry} ${field.hint} ${field.contentDescription} ${field.className}".lowercase()

            val userRegex = Regex("(?i)\\b(user|username|email|correo|usuario|login|account|usr|rfc|curp|nss|id|dni|cedula|identidad|identificacion)\\b")
            val passRegex = Regex("(?i)\\b(password|contraseña|clave|pwd|passcode|pin|contrasena|ciec|fiel|nip|token)\\b")
            val noiseRegex = Regex("(?i)\\b(search|buscar|query|chat|comment|mensaje|address|phone|tel|captcha)\\b")

            if (userRegex.containsMatchIn(contextText)) uScore += 30
            if (passRegex.containsMatchIn(contextText)) pScore += 30
            if (noiseRegex.containsMatchIn(contextText) || isMultiline) {
                uScore -= 100
                pScore -= 100
            }

            scores[field.id]?.apply {
                usernameScore = uScore
                passwordScore = pScore
            }
        }

        val bestPasswordIndex = allFields.indexOfFirst {
            (scores[it.id]?.passwordScore ?: 0) >= 50
        }
        if (bestPasswordIndex > 0) {
            val prevField = allFields[bestPasswordIndex - 1]
            scores[prevField.id]?.let {
                if (it.usernameScore >= 0) it.usernameScore += 40
            }
        }

        val bestUsername = scores.values
            .maxByOrNull { it.usernameScore }
            ?.takeIf { it.usernameScore >= MIN_SCORE_THRESHOLD }?.id

        val bestPassword = scores.values
            .maxByOrNull { it.passwordScore }
            ?.takeIf { it.passwordScore >= MIN_SCORE_THRESHOLD }?.id

        return LoginFields().apply {
            bestUsername?.let { usernameIds.add(it) }
            bestPassword?.let { passwordIds.add(it) }
        }
    }

    private fun collectFields(node: AssistStructure.ViewNode, list: MutableList<FieldInfo>) {
        val className = node.className?.toString() ?: ""
        val isNativeInput = node.inputType != 0 || className.contains("EditText", ignoreCase = true)

        var isHtmlInput = false
        var htmlHints: Array<String>? = null

        if (node.htmlInfo != null && "input" == node.htmlInfo?.tag) {
            isHtmlInput = true
            htmlHints = node.htmlInfo?.attributes
                ?.filter { it.first in listOf("autocomplete", "name", "id", "type") }
                ?.map { it.second }
                ?.toTypedArray()
        }

        val isVisibleAndSized =
            node.visibility == View.VISIBLE && node.width > 0 && node.height > 0

        if (node.autofillId != null && (isNativeInput || isHtmlInput) && isVisibleAndSized) {
            val effectiveHints = when {
                htmlHints != null -> (node.autofillHints ?: emptyArray()) + htmlHints
                else -> node.autofillHints
            }
            list.add(
                FieldInfo(
                    id = node.autofillId!!,
                    hint = node.hint?.toString() ?: "",
                    idEntry = node.idEntry?.toString() ?: "",
                    text = node.text?.toString() ?: "",
                    contentDescription = node.contentDescription?.toString() ?: "",
                    inputType = node.inputType,
                    autofillHints = effectiveHints,
                    className = className,
                    isFocused = node.isFocused,
                    visibility = node.visibility ?: View.VISIBLE
                )
            )
        }

        for (i in 0 until node.childCount) collectFields(node.getChildAt(i), list)
    }

    // ==================== GUARDADO ====================

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        try {
            val context = request.fillContexts.lastOrNull() ?: run {
                callback.onSuccess()
                return
            }
            val structure = context.structure
            val fields = detectLoginFields(structure)

            val username = fields.usernameIds.firstOrNull()
                ?.let { getTextFromNode(structure, it) } ?: ""
            val password = fields.passwordIds.firstOrNull()
                ?.let { getTextFromNode(structure, it) } ?: ""

            if (password.isNotEmpty()) {
                val packageId = structure.activityComponent.packageName
                val appName = getAppName(packageId)
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    action = "SAVE_NEW_PASSWORD"
                    putExtra("app_name", appName)
                    putExtra("package_id", packageId)
                    putExtra("username", username)
                    putExtra("password", password)
                }
                startActivity(intent)
            }
            callback.onSuccess()
        } catch (e: Exception) {
            Log.e(TAG, "Error en onSaveRequest", e)
            callback.onSuccess()
        }
    }

    private fun configureSaveInfo(responseBuilder: FillResponse.Builder, fields: LoginFields) {
        val saveIds = fields.usernameIds + fields.passwordIds
        if (saveIds.isNotEmpty()) {
            val saveInfo = SaveInfo.Builder(
                SaveInfo.SAVE_DATA_TYPE_USERNAME or SaveInfo.SAVE_DATA_TYPE_PASSWORD,
                saveIds.toTypedArray()
            ).build()
            responseBuilder.setSaveInfo(saveInfo)
        }
    }

    // ==================== UTILIDADES ====================

    private fun findMatchingPasswords(
        passwordList: Map<String, PasswordEntry>,
        currentPackage: String
    ): Map<String, PasswordEntry> {
        val packageLower = currentPackage.lowercase(Locale.ROOT)
        val packageSegments = packageLower.split(".")

        return passwordList.filter { (_, entry) ->
            val appClean = entry.app.lowercase(Locale.ROOT).replace(" ", "").replace(".", "")
            val packageIdLower = entry.packageId?.lowercase(Locale.ROOT) ?: ""

            if (packageIdLower == packageLower) return@filter true

            val isInSegments = appClean.split(".").any { frag ->
                frag.length > 4 && packageSegments.contains(frag)
            }
            if (isInSegments) return@filter true

            if (appClean.length > 4 && packageLower.contains(appClean)) return@filter true

            false
        }
    }

    private fun parsePasswords(json: String): Map<String, PasswordEntry> = try {
        val type = object : TypeToken<Map<String, PasswordEntry>>() {}.type
        Gson().fromJson(json, type)
    } catch (e: Exception) {
        Log.e(TAG, "Error al parsear bóveda", e)
        emptyMap()
    }

    private fun saveVaultSilently(repository: SecureRepository, data: Map<String, PasswordEntry>) {
        try {
            repository.saveVault(Gson().toJson(data))
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo guardar bóveda: ${e.message}")
        }
    }

    private fun getAppName(packageId: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(packageId, 0)
        ).toString()
    } catch (e: Exception) {
        packageId.split(".").lastOrNull()
            ?.replaceFirstChar {
                if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString()
            } ?: "App"
    }

    private fun getTextFromNode(structure: AssistStructure, id: AutofillId): String =
        findNodeById(structure, id)?.autofillValue?.textValue?.toString() ?: ""

    private fun findNodeById(structure: AssistStructure, id: AutofillId): AssistStructure.ViewNode? {
        for (i in 0 until structure.windowNodeCount) {
            val found = findNodeInTree(structure.getWindowNodeAt(i).rootViewNode, id)
            if (found != null) return found
        }
        return null
    }

    private fun findNodeInTree(node: AssistStructure.ViewNode, id: AutofillId): AssistStructure.ViewNode? {
        if (node.autofillId == id) return node
        for (i in 0 until node.childCount) {
            val found = findNodeInTree(node.getChildAt(i), id)
            if (found != null) return found
        }
        return null
    }

    // ==================== DATA CLASSES ====================

    @Keep
    private data class ScoredField(
        val id: AutofillId,
        var usernameScore: Int = 0,
        var passwordScore: Int = 0
    )

    @Keep
    private data class LoginFields(
        val usernameIds: MutableList<AutofillId> = mutableListOf(),
        val passwordIds: MutableList<AutofillId> = mutableListOf()
    )

    @Keep
    private data class FieldInfo(
        val id: AutofillId,
        val hint: String,
        val idEntry: String,
        val text: String,
        val contentDescription: String,
        val inputType: Int,
        val autofillHints: Array<String>?,
        val className: String,
        val isFocused: Boolean,
        val visibility: Int
    )

    @Keep
    data class PasswordEntry(
        @SerializedName("app") val app: String,
        @SerializedName("username") val username: String?,
        @SerializedName("password") val password: String,
        @SerializedName("packageId") val packageId: String? = null
    )
}