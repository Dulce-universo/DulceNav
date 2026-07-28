// ============================================================
// DulceNav — android/build.gradle (nivel raíz)
// ============================================================
buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    project.evaluationDependsOn(":app")

    // Strip package attribute in library manifests to resolve AGP 8.0+ build failures
    try {
        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            var content = manifestFile.readText()
            if (content.contains("package=")) {
                content = content.replace(Regex("""package="[^"]+""""), "")
                manifestFile.writeText(content)
                project.logger.lifecycle("Patched AndroidManifest.xml for ${project.name}: stripped package attribute")
            }
        }
    } catch (e: Exception) {
        // Ignore
    }

    fun configureNamespace(proj: Project) {
        val android = proj.extensions.findByName("android")
        if (android != null) {
            val hasNamespace = try {
                android.javaClass.getMethod("getNamespace").invoke(android) != null
            } catch (e: Exception) {
                false
            }
            if (!hasNamespace) {
                try {
                    android.javaClass.getMethod("setNamespace", String::class.java).invoke(android, "com.dulcenav.fallback." + proj.name.replace("-", "."))
                } catch (e: Exception) {
                    // Ignore
                }
            }
        }
    }

    plugins.withId("com.android.library") {
        configureNamespace(project)
    }
    plugins.withId("com.android.application") {
        configureNamespace(project)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
