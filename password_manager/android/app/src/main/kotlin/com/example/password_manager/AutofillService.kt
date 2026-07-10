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
            val packageName = structure.activityComponent?.packageName ?: ""
            val webDomain = extractWebDomain(structure)
            val effectiveAppName = webDomain ?: getAppName(packageName)
            Log.d(TAG, "onFillRequest para: $packageName (Dominio: $webDomain)")

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
                val matches = findMatchingPasswords(passwordList, packageName, webDomain)
                var vaultWasModified = false

                Log.d(TAG, "Credenciales coincidentes: ${matches.size}")

                if (matches.isNotEmpty()) {
                    val inlineRequest: InlineSuggestionsRequest? =
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                            request.inlineSuggestionsRequest
                        else null

                    // Respetar el límite de sugerencias inline del teclado
                    val maxInline = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                        inlineRequest?.maxSuggestionCount ?: Int.MAX_VALUE
                    else Int.MAX_VALUE

                    matches.entries.forEachIndexed { index, (key, entry) ->
                        val uniqueRequestCode = (key + index).hashCode()
                        // Solo pasar inlineRequest si no hemos excedido el límite
                        val effectiveInlineReq = if (index < maxInline - 1) inlineRequest else null
                        val dataset = buildAuthenticatedDataset(
                            entry = entry,
                            fields = fields,
                            targetPackage = packageName,
                            inlineRequest = effectiveInlineReq,
                            uniqueRequestCode = uniqueRequestCode
                        )
                        responseBuilder.addDataset(dataset)

                        if (entry.packageId.isNullOrEmpty()) {
                            passwordList[key] = entry.copy(packageId = packageName)
                            vaultWasModified = true
                        }
                    }

                    // Chip piñado "Abrir Password Manager" como fallback
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && inlineRequest != null) {
                        try {
                            val openAppDataset = buildOpenAppInlineDataset(inlineRequest, fields)
                            if (openAppDataset != null) {
                                responseBuilder.addDataset(openAppDataset)
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "No se pudo crear chip de fallback: ${e.message}")
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

    /**
     * Chip piñado (pinned) que aparece al final de la barra inline del teclado.
     * Si el usuario no encuentra su cuenta, puede tocar este chip para abrir
     * la app completa y buscar manualmente.
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun buildOpenAppInlineDataset(
        inlineRequest: InlineSuggestionsRequest,
        fields: LoginFields
    ): Dataset? {
        val specs = inlineRequest.inlinePresentationSpecs
        if (specs.isEmpty()) return null

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingFlags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val pendingIntent = PendingIntent.getActivity(
            this, "open_app_chip".hashCode(), openAppIntent, pendingFlags
        )

        val content = InlineSuggestionUi
            .newContentBuilder(pendingIntent)
            .setTitle("🔑 Buscar en bóveda")
            .setStartIcon(
                android.graphics.drawable.Icon.createWithResource(this, R.mipmap.ic_launcher)
            )
            .build()

        // El último spec es el piñado
        val pinnedSpec = specs[specs.size - 1]
        val inlinePresentation = InlinePresentation(content.slice, pinnedSpec, true)

        val dropdownView = RemoteViews(packageName, R.layout.autofill_item).apply {
            setTextViewText(R.id.autofill_title, "🔑 Buscar en bóveda")
            setTextViewText(R.id.autofill_subtitle, "Abrir Password Manager")
        }

        val datasetBuilder = Dataset.Builder(dropdownView)
        datasetBuilder.setInlinePresentation(inlinePresentation)
        datasetBuilder.setAuthentication(pendingIntent.intentSender)

        val allIds = fields.usernameIds + fields.passwordIds
        for (id in allIds) {
            datasetBuilder.setValue(id, null, dropdownView)
        }

        return datasetBuilder.build()
    }

    // ==================== DETECCIÓN HEURÍSTICA DE CAMPOS ====================

    /**
     * Sistema de puntuación de campos mejorado.
     * 
     * Prioridades de detección (de mayor a menor peso):
     * 1. autofillHints estándar de Android (View.AUTOFILL_HINT_*)
     * 2. Atributos HTML (type, autocomplete, name, id)
     * 3. InputType del sistema (TYPE_TEXT_VARIATION_PASSWORD, etc.)
     * 4. Texto contextual (hint, idEntry, contentDescription)
     * 5. Heurística posicional (campo anterior a contraseña = usuario)
     */
    private fun detectLoginFields(structure: AssistStructure): LoginFields {
        val allFields = mutableListOf<FieldInfo>()
        for (i in 0 until structure.windowNodeCount) {
            collectFields(structure.getWindowNodeAt(i).rootViewNode, allFields)
        }

        val scores = allFields.associateBy({ it.id }, { ScoredField(it.id) })

        for (field in allFields) {
            var uScore = 0
            var pScore = 0

            // ── 1. AUTOFILL HINTS ESTÁNDAR (máxima prioridad) ──
            val hints = field.autofillHints
            if (hints != null) {
                for (h in hints) {
                    val hLower = h.lowercase(Locale.ROOT)
                    when {
                        hLower == View.AUTOFILL_HINT_USERNAME.lowercase() -> uScore += 60
                        hLower == View.AUTOFILL_HINT_EMAIL_ADDRESS.lowercase() -> uScore += 55
                        hLower == View.AUTOFILL_HINT_PHONE.lowercase() -> uScore += 35
                        hLower == View.AUTOFILL_HINT_PASSWORD.lowercase() -> pScore += 60
                        // W3C autocomplete values que Android pasa como hint
                        hLower == "current-password" -> pScore += 60
                        hLower == "new-password" -> pScore += 40
                        hLower == "username" -> uScore += 60
                        hLower == "email" -> uScore += 55
                        hLower == "tel" -> uScore += 35
                    }
                }
            }

            // ── 2. ATRIBUTOS HTML (navegadores web) ──
            val htmlAttrs = field.htmlAttributes
            if (htmlAttrs != null) {
                val htmlType = htmlAttrs["type"]?.lowercase(Locale.ROOT) ?: ""
                val htmlAutocomplete = htmlAttrs["autocomplete"]?.lowercase(Locale.ROOT) ?: ""
                val htmlName = htmlAttrs["name"]?.lowercase(Locale.ROOT) ?: ""
                val htmlId = htmlAttrs["id"]?.lowercase(Locale.ROOT) ?: ""

                // type="password" es la señal más fuerte en HTML
                if (htmlType == "password") pScore += 55
                // type="email" o type="tel" indican campo de usuario
                if (htmlType == "email" || htmlType == "tel") uScore += 45

                // autocomplete es el estándar W3C
                if (htmlAutocomplete.contains("password") || htmlAutocomplete.contains("current-password")) pScore += 55
                if (htmlAutocomplete == "new-password") pScore += 35
                if (htmlAutocomplete.contains("username") || htmlAutocomplete.contains("email")) uScore += 50
                if (htmlAutocomplete.contains("tel")) uScore += 30

                // name e id del elemento HTML
                val htmlContext = "$htmlName $htmlId"
                val htmlUserRegex = Regex("(?i)(user|email|login|account|correo|usuario|rfc|curp)")
                val htmlPassRegex = Regex("(?i)(pass|pwd|clave|contrase|pin|nip)")
                if (htmlUserRegex.containsMatchIn(htmlContext)) uScore += 30
                if (htmlPassRegex.containsMatchIn(htmlContext)) pScore += 30

                // Excluir campos de búsqueda HTML
                val htmlNoiseRegex = Regex("(?i)(search|query|filter|subscribe|newsletter|register_email)")
                if (htmlNoiseRegex.containsMatchIn(htmlContext) || htmlAutocomplete == "off") {
                    uScore -= 40
                    pScore -= 40
                }
            }

            // ── 3. INPUT TYPE del sistema Android ──
            val inputType = field.inputType
            val isMultiline = (inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE) != 0 ||
                              (inputType and InputType.TYPE_TEXT_FLAG_IME_MULTI_LINE) != 0

            val typeVariation = inputType and InputType.TYPE_MASK_VARIATION
            val typeClass = inputType and InputType.TYPE_MASK_CLASS

            val isTextPassword = typeVariation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                                 typeVariation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                                 typeVariation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
            val isNumberPassword = typeClass == InputType.TYPE_CLASS_NUMBER &&
                                   typeVariation == InputType.TYPE_NUMBER_VARIATION_PASSWORD
            if (isTextPassword || isNumberPassword) pScore += 50

            val isEmail = typeVariation == InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS ||
                          typeVariation == InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS
            if (isEmail) uScore += 40

            val isPhone = typeClass == InputType.TYPE_CLASS_PHONE
            if (isPhone) uScore += 25

            // ── 4. TEXTO CONTEXTUAL (hint, idEntry, contentDescription) ──
            val contextText = listOf(
                field.idEntry, field.hint, field.contentDescription
            ).joinToString(" ").lowercase(Locale.ROOT)

            val userRegex = Regex("(?i)\\b(user|username|email|e-mail|correo|usuario|login|account|usr|rfc|curp|nss|dni|cedula|identidad|identificacion|matricula|folio|numero.?de.?cliente|phone|telefono|celular)\\b")
            val passRegex = Regex("(?i)\\b(password|contraseña|clave|pwd|passcode|pin|contrasena|ciec|fiel|nip|token|secret|codigo.?de.?acceso)\\b")
            val noiseRegex = Regex("(?i)\\b(search|buscar|busqueda|query|chat|comment|comentario|mensaje|message|address|direccion|captcha|otp|verification|codigo.?de.?verificacion|nombre.?completo|full.?name|first.?name|last.?name|apellido|city|ciudad|state|estado|zip|postal|country|pais|subscribe|promo|coupon|cupon)\\b")

            if (userRegex.containsMatchIn(contextText)) uScore += 30
            if (passRegex.containsMatchIn(contextText)) pScore += 30

            // Penalizaciones fuertes por campos de ruido
            if (noiseRegex.containsMatchIn(contextText) || isMultiline) {
                uScore -= 100
                pScore -= 100
            }

            scores[field.id]?.apply {
                usernameScore = uScore
                passwordScore = pScore
            }
        }

        // ── 5. HEURÍSTICA POSICIONAL ──
        // El campo inmediatamente anterior a una contraseña con alta confianza
        // casi siempre es el campo de usuario. También revisamos 2 campos atrás
        // para formularios con campos intermedios (ej: "recordar sesión" checkbox).
        val passwordCandidates = allFields.indices.filter {
            (scores[allFields[it].id]?.passwordScore ?: 0) >= 40
        }

        for (pwIdx in passwordCandidates) {
            // Campo inmediatamente anterior
            if (pwIdx > 0) {
                val prevField = allFields[pwIdx - 1]
                scores[prevField.id]?.let {
                    if (it.usernameScore >= -10 && it.passwordScore < 30) {
                        it.usernameScore += 40
                    }
                }
            }
            // Dos campos atrás (para formularios con checkboxes intermedios)
            if (pwIdx > 1) {
                val prev2Field = allFields[pwIdx - 2]
                scores[prev2Field.id]?.let {
                    if (it.usernameScore >= 0 && it.passwordScore < 20) {
                        it.usernameScore += 20
                    }
                }
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
        var htmlAttributes: Map<String, String>? = null
        var htmlHints: Array<String>? = null

        if (node.htmlInfo != null && "input" == node.htmlInfo?.tag) {
            isHtmlInput = true
            val attrs = node.htmlInfo?.attributes
            if (attrs != null) {
                // Extraer atributos HTML relevantes como mapa para análisis detallado
                htmlAttributes = attrs
                    .filter { it.first in listOf("autocomplete", "name", "id", "type", "placeholder", "aria-label") }
                    .associate { it.first to it.second }
                // También mantenerlos como hints para compatibilidad
                htmlHints = attrs
                    .filter { it.first in listOf("autocomplete", "name", "id", "type") }
                    .map { it.second }
                    .toTypedArray()
            }
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
                    htmlAttributes = htmlAttributes,
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
                val packageId = structure.activityComponent?.packageName ?: ""
                val webDomain = extractWebDomain(structure)
                val appName = webDomain ?: getAppName(packageId)
                
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
        currentPackage: String,
        webDomain: String? = null
    ): Map<String, PasswordEntry> {
        val packageLower = currentPackage.lowercase(Locale.ROOT)
        val packageSegments = packageLower.split(".")
        val domainLower = webDomain?.lowercase(Locale.ROOT)

        return passwordList.filter { (_, entry) ->
            val appClean = entry.app.lowercase(Locale.ROOT).replace(" ", "").replace(".", "")
            val packageIdLower = entry.packageId?.lowercase(Locale.ROOT) ?: ""

            if (packageIdLower == packageLower) return@filter true
            if (domainLower != null && domainLower.contains(appClean)) return@filter true
            if (domainLower != null && appClean.contains(domainLower.replace(".com", "").replace(".net", "").replace(".org", ""))) return@filter true

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

    private fun extractWebDomain(structure: AssistStructure): String? {
        for (i in 0 until structure.windowNodeCount) {
            val domain = findWebDomainInNode(structure.getWindowNodeAt(i).rootViewNode)
            if (domain != null) return domain
        }
        return null
    }

    private fun findWebDomainInNode(node: AssistStructure.ViewNode): String? {
        val fullDomain = node.webDomain
        if (fullDomain != null) {
            return try {
                val uri = android.net.Uri.parse(if (!fullDomain.startsWith("http")) "https://$fullDomain" else fullDomain)
                uri.host?.removePrefix("www.")?.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString()
                } ?: fullDomain
            } catch (e: Exception) {
                fullDomain
            }
        }
        for (i in 0 until node.childCount) {
            val domain = findWebDomainInNode(node.getChildAt(i))
            if (domain != null) return domain
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
        val htmlAttributes: Map<String, String>?,
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