package org.pepoconnect.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UpdatePackagePolicyTest {
    private val installed = UpdatePackageMetadata("org.pepoconnect.app", "1.2.2", 2002L, setOf("release-key"))
    private val update = UpdatePackageMetadata("org.pepoconnect.app", "1.2.3", 2003L, setOf("release-key"))

    @Test fun acceptsNewerVersionOfSameSignedApplication() {
        assertNull(UpdatePackagePolicy.rejection(installed, update, "1.2.3"))
    }

    @Test fun rejectsDifferentPackageAndSigningCertificate() {
        assertEquals("package", UpdatePackagePolicy.rejection(installed, update.copy(packageName = "other.app"), "1.2.3"))
        assertEquals("signature", UpdatePackagePolicy.rejection(installed, update.copy(signers = setOf("debug-key")), "1.2.3"))
        assertEquals("signature", UpdatePackagePolicy.rejection(installed, update.copy(signers = emptySet()), "1.2.3"))
    }

    @Test fun rejectsWrongReleaseAndDowngradeIncludingSplitApkCodes() {
        assertEquals("version", UpdatePackagePolicy.rejection(installed, update.copy(versionName = "1.2.1"), "1.2.3"))
        assertEquals("version", UpdatePackagePolicy.rejection(installed, update.copy(versionCode = 3), "1.2.3"))
        assertEquals("version", UpdatePackagePolicy.rejection(installed, update.copy(versionCode = 2002L), "1.2.3"))
    }
}
