package org.pepoconnect.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ExecutorService

/** This provider exposes only cache/updates, never user transfers or app data. */
class PepoUpdateFileProvider : FileProvider()

/** APK verification happens off the UI thread, before requesting any permission. */
internal object PepoUpdater {
    fun cacheDirectory(context: Context): File = File(context.cacheDir, "updates").apply {
        if (!isDirectory && !mkdirs()) throw IllegalStateException("Cannot create update cache")
    }

    fun canInstall(context: Context): Boolean = context.packageManager.canRequestPackageInstalls()

    fun install(
        context: Context,
        activity: Activity?,
        call: MethodCall,
        result: MethodChannel.Result,
        io: ExecutorService,
        main: Handler,
    ) {
        val path = call.argument<String>("path")
        val checksum = call.argument<String>("sha256")
        val size = call.argument<Number>("size")?.toLong()
        val version = call.argument<String>("version")
        if (path.isNullOrBlank() || checksum == null || size == null || version.isNullOrBlank()) {
            result.error("verification", "Incomplete update metadata", null)
            return
        }
        io.execute {
            val verified = runCatching { verify(context, path, checksum, size, version) }
            main.post {
                verified.fold(
                    onSuccess = { apk ->
                        try {
                            // The verified file remains cached when the permission page is
                            // opened. Dart resumes this operation only once permission exists.
                            if (!canInstall(context)) {
                                val permission = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:${context.packageName}"))
                                launch(context, activity, permission)
                                result.success("permissionRequired")
                            } else {
                                val uri = FileProvider.getUriForFile(context, "${context.packageName}.update-files", apk)
                                val install = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                launch(context, activity, install)
                                result.success("installerOpened")
                            }
                        } catch (e: ActivityNotFoundException) {
                            result.error("unsupported", "No system package installer is available", null)
                        } catch (e: SecurityException) {
                            result.error("permission", e.message ?: "Android refused the installer", null)
                        } catch (e: Exception) {
                            result.error("install", e.message ?: "Could not open the installer", null)
                        }
                    },
                    onFailure = { error -> result.error("verification", error.message ?: "APK verification failed", null) },
                )
            }
        }
    }

    private fun launch(context: Context, activity: Activity?, intent: Intent) {
        if (activity != null && !activity.isFinishing && !activity.isDestroyed) activity.startActivity(intent)
        else context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    @Suppress("DEPRECATION") // API 29 is supported; the integer flag overload is valid through API 36.
    private fun verify(context: Context, path: String, checksum: String, expectedSize: Long, expectedVersion: String): File {
        val root = cacheDirectory(context).canonicalFile
        val apk = File(path).canonicalFile
        require(apk.path.startsWith(root.path + File.separator) && apk.isFile && apk.extension == "apk") { "APK is outside the private update cache" }
        require(expectedSize in 1L..(1024L * 1024L * 1024L) && apk.length() == expectedSize) { "APK size does not match the release" }
        require(checksum.matches(Regex("[a-f0-9]{64}"))) { "Invalid APK checksum" }
        val digest = MessageDigest.getInstance("SHA-256")
        apk.inputStream().buffered().use { input ->
            val buffer = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                require(total <= expectedSize) { "APK changed during verification" }
                digest.update(buffer, 0, count)
            }
            require(total == expectedSize) { "APK is incomplete" }
        }
        require(hex(digest.digest()) == checksum) { "APK checksum does not match the release" }
        val manager = context.packageManager
        val candidate = manager.getPackageArchiveInfo(apk.path, PackageManager.GET_SIGNING_CERTIFICATES)
            ?: throw IllegalArgumentException("Android could not read the APK")
        val installed = manager.getPackageInfo(context.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        val rejection = UpdatePackagePolicy.rejection(metadata(installed), metadata(candidate), expectedVersion)
        require(rejection == null) { "APK $rejection does not match an eligible update" }
        return apk
    }

    private fun metadata(info: PackageInfo): UpdatePackageMetadata = UpdatePackageMetadata(
        info.packageName, info.versionName, info.longVersionCode,
        info.signingInfo?.apkContentsSigners?.map {
            hex(MessageDigest.getInstance("SHA-256").digest(it.toByteArray()))
        }?.toSet() ?: emptySet(),
    )

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
}
