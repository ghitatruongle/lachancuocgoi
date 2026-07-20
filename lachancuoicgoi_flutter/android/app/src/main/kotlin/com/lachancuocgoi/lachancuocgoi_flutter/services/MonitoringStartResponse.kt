package com.lachancuocgoi.lachancuocgoi_flutter.services

/** Wire statuses consumed by Flutter's typed MonitoringStartResult parser. */
enum class MonitoringStartStatus(val wireValue: String) {
    STARTED("started"),
    ALREADY_RUNNING("alreadyRunning"),
    PERMISSION_DENIED("permissionDenied"),
    BACKGROUND_START_DENIED("backgroundStartDenied"),
    NATIVE_FAILURE("nativeFailure"),
}

data class MonitoringStartResponse(
    val status: MonitoringStartStatus,
    val message: String,
) {
    fun toMap(): Map<String, String> = mapOf(
        "status" to status.wireValue,
        "message" to message,
    )
}
