package org.pepoconnect.app

/** Values read by PackageManager, kept separate so validation has JVM tests. */
internal data class UpdatePackageMetadata(
    val packageName: String,
    val versionName: String?,
    val versionCode: Long,
    val signers: Set<String>,
)

internal object UpdatePackagePolicy {
    fun rejection(installed: UpdatePackageMetadata, candidate: UpdatePackageMetadata, expectedVersion: String): String? {
        if (candidate.packageName != installed.packageName) return "package"
        if (candidate.signers.isEmpty() || candidate.signers != installed.signers) return "signature"
        if (candidate.versionName?.substringBefore('+') != expectedVersion || candidate.versionCode <= installed.versionCode) return "version"
        return null
    }
}
