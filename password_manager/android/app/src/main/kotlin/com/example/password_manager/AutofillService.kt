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
import android.view.autofill.AutofillValue
import android.view.inputmethod.InlineSuggestionsRequest
import android.widget.RemoteViews
import android.widget.inline.InlinePresentationSpec
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
        private const val MIN_SCORE_THRESHOLD = 30 // Umbral más alto debido a la nueva escala de puntuación
    }

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

            // 1. Motor Heurístico Sofisticado
            val fields = detectLoginFieldsSophisticated(structure)
            
            if (fields.passwordIds.isEmpty() && fields.usernameIds.isEmpty()) {
                callback.onSuccess(null)
                return
            }

            val responseBuilder = FillResponse.Builder()
            configureSaveInfo(responseBuilder, fields)

            // 2. Extracción de Bóveda
            val repository = SecureRepository(this)
            val jsonString = repository.getVault()

            if (jsonString != null) {
                val passwordList = parsePasswords(jsonString).toMutableMap()
                val matches = findMatchingPasswords(passwordList, packageName)
                var vaultWasModified = false

                if (matches.isNotEmpty()) {
                    var inlineRequest: InlineSuggestionsRequest? = null
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        inlineRequest = request.inlineSuggestionsRequest
                    }
                    
                    for ((key, entry) in matches) {
                        val dataset = createAuthenticatedDataset(
                            entry, 
                            fields, 
                            packageName, 
                            inlineRequest
                        )
                        responseBuilder.addDataset(dataset)

                        if (entry.packageId.isNullOrEmpty()) {
                            val updatedEntry = entry.copy(packageId = packageName)
                            passwordList[key] = updatedEntry
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

    // ==================== CREACIÓN DE DATASET ====================

    private fun createAuthenticatedDataset(
        entry: PasswordEntry, 
        fields: LoginFields,
        targetPackage: String,
        inlineRequest: InlineSuggestionsRequest?
    ): Dataset {
        val dropdownPresentation = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_title, "🔐 ${entry.app}")
            setTextViewText(R.id.autofill_subtitle, entry.username ?: "Desbloquear")
        }

        val authIntent = Intent(this, AuthenticationActivity::class.java).apply {
            putExtra("app_name", entry.app)
            putExtra("username", entry.username)
            putExtra("password", entry.password)
            putExtra("target_package", targetPackage)
            putParcelableArrayListExtra("username_ids", ArrayList(fields.usernameIds))
            putParcelableArrayListExtra("password_ids", ArrayList(fields.passwordIds))
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            entry.app.hashCode(),
            authIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_CANCEL_CURRENT
        )

        var inlinePresentation: InlinePresentation? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && inlineRequest != null) {
            val specs = inlineRequest.inlinePresentationSpecs
            if (specs.isNotEmpty()) {
                val spec = specs[0]
                val contentBuilder = InlineSuggestionUi.newContentBuilder(pendingIntent)
                    .setTitle("🔐 ${entry.app}")
                    .setSubtitle(entry.username ?: "Desbloquear")
                    .setStartIcon(android.graphics.drawable.Icon.createWithResource(this, R.mipmap.ic_launcher))
                
                val content = contentBuilder.build()
                inlinePresentation = InlinePresentation(content.slice, spec, false)
            }
        }

        val datasetBuilder = Dataset.Builder(dropdownPresentation)
        datasetBuilder.setAuthentication(pendingIntent.intentSender)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && inlinePresentation != null) {
            datasetBuilder.setInlinePresentation(inlinePresentation, inlinePresentation)
        }

        val allIds = fields.usernameIds + fields.passwordIds
        for (id in allIds) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && inlinePresentation != null) {
                datasetBuilder.setValue(id, AutofillValue.forText(" ••••• "), dropdownPresentation, inlinePresentation)
            } else {
                datasetBuilder.setValue(id, AutofillValue.forText(" ••••• "), dropdownPresentation)
            }
        }

        return datasetBuilder.build()
    }

    // ==================== NUEVO MOTOR HEURÍSTICO AVANZADO ====================
    
    private fun detectLoginFieldsSophisticated(structure: AssistStructure): LoginFields {
        val allFields = mutableListOf<FieldInfo>()
        for (i in 0 until structure.windowNodeCount) {
            collectAllFields(structure.getWindowNodeAt(i).rootViewNode, allFields)
        }
        
        val scores = mutableMapOf<AutofillId, ScoredField>()
        allFields.forEach { scores[it.id] = ScoredField(it.id) }
        
        // Fase 1: Análisis Heurístico Estricto (Regex y Tipos nativos)
        for (field in allFields) {
            var uScore = 0
            var pScore = 0
            
            val inputType = field.inputType
            val isMultiline = (inputType and InputType.TYPE_TEXT_FLAG_IME_MULTI_LINE) != 0
            
            // 1. Detección por Tipo Nativo (Señales más fuertes de Android)
            val isTextPassword = (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                                 (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
            val isNumberPassword = (inputType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_NUMBER &&
                                   (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_NUMBER_VARIATION_PASSWORD
            if (isTextPassword || isNumberPassword) pScore += 60

            val isEmail = (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                          (inputType and InputType.TYPE_MASK_VARIATION) == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS
            if (isEmail) uScore += 40

            // 2. Detección por Hints (Señales de Frameworks modernos y W3C)
            val hintsJoined = field.autofillHints?.joinToString(" ")?.lowercase() ?: ""
            if (hintsJoined.contains("username") || hintsJoined.contains("email")) uScore += 50
            if (hintsJoined.contains("current-password")) pScore += 50 // Mayor prioridad a login actual
            if (hintsJoined.contains("new-password")) pScore += 20 // Menor prioridad para evitar rellenar en registros
            if (hintsJoined == "password") pScore += 40

            // 3. Análisis Regex Heurístico en Texto Contextual
            val contextualText = "${field.idEntry} ${field.hint} ${field.contentDescription} ${field.className}".lowercase()
            
            // Boundaries (\b) aseguran que matcheamos palabras enteras, evitando falsos positivos.
            // Se han añadido identificadores universales e institucionales (rfc, curp, nss, id, dni, cedula)
            val userRegex = Regex("(?i)\\b(user|username|email|correo|usuario|login|account|usr|rfc|curp|nss|id|dni|cedula|identidad|identificacion)\\b")
            
            // Se añadieron términos específicos de contraseñas fiscales y de seguridad (ciec, fiel, nip, token)
            val passRegex = Regex("(?i)\\b(password|contraseña|clave|pwd|passcode|pin|contrasena|ciec|fiel|nip|token)\\b")
            
            if (userRegex.containsMatchIn(contextualText)) uScore += 30
            if (passRegex.containsMatchIn(contextualText)) pScore += 30

            // 4. Sistema de Penalización (Negative Scoring)
            // En lugar de bloquear de tajo, castigamos matemáticamente campos que parecen ser búsquedas o basura.
            val nuisanceRegex = Regex("(?i)\\b(search|buscar|query|chat|comment|mensaje|address|phone|tel|captcha)\\b")
            if (nuisanceRegex.containsMatchIn(contextualText) || isMultiline) {
                uScore -= 100
                pScore -= 100
            }

            scores[field.id]?.apply {
                usernameScore = uScore
                passwordScore = pScore
            }
        }

        // Fase 2: Análisis de Proximidad Relacional (Contexto Visual)
        // La inteligencia humana asume que si el campo [1] es contraseña, el [0] probablemente sea el usuario.
        // Solo aplicamos este bono a campos de texto que no hayan sido penalizados negativamente.
        val bestPasswordIndex = allFields.indexOfFirst { (scores[it.id]?.passwordScore ?: 0) >= 50 }
        if (bestPasswordIndex > 0) {
            val previousField = allFields[bestPasswordIndex - 1]
            val prevScore = scores[previousField.id]
            if (prevScore != null && prevScore.usernameScore >= 0) {
                // Impulso relacional enorme por proximidad
                prevScore.usernameScore += 40
            }
        }
        
        // Fase 3: Selección de Ganadores Absolutos
        val bestUsername = scores.values.maxByOrNull { it.usernameScore }?.takeIf { it.usernameScore >= MIN_SCORE_THRESHOLD }?.id
        val bestPassword = scores.values.maxByOrNull { it.passwordScore }?.takeIf { it.passwordScore >= MIN_SCORE_THRESHOLD }?.id
        
        val resultFields = LoginFields()
        bestUsername?.let { resultFields.usernameIds.add(it) }
        bestPassword?.let { resultFields.passwordIds.add(it) }
        
        return resultFields
    }

    private fun collectAllFields(node: AssistStructure.ViewNode, list: MutableList<FieldInfo>) {
        val className = node.className?.toString() ?: ""
        val isNativeInput = node.inputType != 0 || className.contains("EditText", ignoreCase = true)
        
        var isHtmlInput = false
        var htmlHints: Array<String>? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && node.htmlInfo != null) {
            if ("input" == node.htmlInfo?.tag) {
                isHtmlInput = true
                node.htmlInfo?.attributes?.forEach { attr ->
                    if (attr.first in listOf("autocomplete", "name", "id", "type")) {
                        val currentHints = htmlHints ?: emptyArray()
                        htmlHints = currentHints + attr.second
                    }
                }
            }
        }

        // Filtrado base visual: Si un nodo es invisible o mide 0, es un tracker o un honeypot, lo ignoramos de raíz.
        val isVisibleAndSized = node.visibility == View.VISIBLE && node.width > 0 && node.height > 0

        if (node.autofillId != null && (isNativeInput || isHtmlInput) && isVisibleAndSized) {
            val effectiveHints = if (htmlHints != null) {
                (node.autofillHints ?: emptyArray()) + htmlHints!!
            } else {
                node.autofillHints
            }

            list.add(FieldInfo(
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
            ))
        }
        for (i in 0 until node.childCount) collectAllFields(node.getChildAt(i), list)
    }

    // ==================== GUARDADO Y UTILIDADES ====================

    private fun configureSaveInfo(responseBuilder: FillResponse.Builder, fields: LoginFields) {
        val saveIds = mutableListOf<AutofillId>()
        saveIds.addAll(fields.usernameIds)
        saveIds.addAll(fields.passwordIds)
        if (saveIds.isNotEmpty()) {
            val saveInfo = SaveInfo.Builder(
                SaveInfo.SAVE_DATA_TYPE_USERNAME or SaveInfo.SAVE_DATA_TYPE_PASSWORD,
                saveIds.toTypedArray()
            ).build()
            responseBuilder.setSaveInfo(saveInfo)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        try {
            val context = request.fillContexts.lastOrNull() ?: run { callback.onSuccess(); return }
            val structure = context.structure
            val fields = detectLoginFieldsSophisticated(structure)
            var username = ""
            var password = ""
            
            if (fields.usernameIds.isNotEmpty()) username = getTextFromNode(structure, fields.usernameIds.first())
            if (fields.passwordIds.isNotEmpty()) password = getTextFromNode(structure, fields.passwordIds.first())

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
        } catch (e: Exception) { callback.onSuccess() }
    }

    private fun saveVaultSilently(repository: SecureRepository, data: Map<String, PasswordEntry>) {
        try { repository.saveVault(Gson().toJson(data)) } catch (e: Exception) { }
    }

    private fun findMatchingPasswords(passwordList: Map<String, PasswordEntry>, currentPackage: String): Map<String, PasswordEntry> {
        val packageLower = currentPackage.lowercase(Locale.ROOT)
        val packageSegments = packageLower.split(".")

        return passwordList.filter { (_, entry) ->
            val appNameClean = entry.app.lowercase(Locale.ROOT).replace(" ", "").replace(".", "")
            val packageIdLower = entry.packageId?.lowercase(Locale.ROOT) ?: ""

            if (packageIdLower == packageLower) return@filter true
            
            val isAppNameInSegments = appNameClean.split(".").any { fragment ->
                fragment.length > 4 && packageSegments.contains(fragment)
            }
            if (isAppNameInSegments) return@filter true

            if (appNameClean.length > 4 && packageLower.contains(appNameClean)) return@filter true

            false
        }
    }

    private fun parsePasswords(json: String): Map<String, PasswordEntry> {
        return try {
            val type = object : TypeToken<Map<String, PasswordEntry>>() {}.type
            Gson().fromJson(json, type)
        } catch (e: Exception) { emptyMap() }
    }

    private fun getAppName(packageId: String): String {
        return try {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageId, 0)).toString()
        } catch (e: Exception) {
            packageId.split(".").lastOrNull()?.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() } ?: "App"
        }
    }

    private fun getTextFromNode(structure: AssistStructure, id: AutofillId): String {
        return findNodeById(structure, id)?.autofillValue?.textValue?.toString() ?: ""
    }

    private fun findNodeById(structure: AssistStructure, id: AutofillId): AssistStructure.ViewNode? {
        for (i in 0 until structure.windowNodeCount) {
            val found = traverseFindNode(structure.getWindowNodeAt(i).rootViewNode, id)
            if (found != null) return found
        }
        return null
    }

    private fun traverseFindNode(node: AssistStructure.ViewNode, id: AutofillId): AssistStructure.ViewNode? {
        if (node.autofillId == id) return node
        for (i in 0 until node.childCount) {
            val found = traverseFindNode(node.getChildAt(i), id)
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