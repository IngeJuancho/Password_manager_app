# ---------------------------------------------------------
# REGLAS CRÍTICAS PARA PASSWORD MANAGER
# ---------------------------------------------------------

# 1. Proteger el Servicio y la Activity (Entradas del Manifiesto)
-keep public class com.example.password_manager.AutofillService { *; }
-keep public class com.example.password_manager.AuthenticationActivity { *; }
-keep public class com.example.password_manager.MainActivity { *; }

# 2. BLINDAJE DE MODELOS DE DATOS (Crucial para Gson)
# Mantenemos nombres de clase Y todos sus miembros (campos/variables)
-keep class com.example.password_manager.AutofillService$PasswordEntry { *; }
-keep class com.example.password_manager.AutofillService$LoginFields { *; }
-keep class com.example.password_manager.AutofillService$FieldInfo { *; }

# 3. REGLAS PARA GSON (Reflexión y Tipos Genéricos)
# Mantiene la información de Generics (<String, PasswordEntry>)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Protege Gson internamente
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }

# Asegura que los nombres serializados (@SerializedName) se respeten
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 4. REGLAS DE FLUTTER Y LIBRERÍAS
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**