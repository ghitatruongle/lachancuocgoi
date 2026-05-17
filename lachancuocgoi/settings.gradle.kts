pluginManagement {
    repositories {
        // Khai báo các kho lưu trữ để Gradle tìm plugin, không cần bộ lọc
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // Khai báo các kho lưu trữ để Gradle tìm thư viện cho app
        google()
        mavenCentral()
    }
}

rootProject.name = "lachancuocgoi"
include(":app")
