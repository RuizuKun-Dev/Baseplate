local VEHICLE_CAMERA_CONFIG = {
	pitchStiffness = 0.5,
	yawStiffness = 2.5,
	autocorrectDelay = 1,
	autocorrectMinCarSpeed = 16,
	autocorrectMaxCarSpeed = 32,
	autocorrectResponse = 0.5,
	cutoffMinAngularVelYaw = 60,
	cutoffMaxAngularVelYaw = 180,
	cutoffMinAngularVelPitch = 15,
	cutoffMaxAngularVelPitch = 60,
	pitchBaseAngle = 18,
	pitchDeadzoneAngle = 12,
	firstPersonResponseMul = 10,
	yawReponseDampingRising = 1,
	yawResponseDampingFalling = 3,
	pitchReponseDampingRising = 1,
	pitchResponseDampingFalling = 3,
	initialZoomRadiusMul = 3,
	verticalCenterOffset = 0.33,
}

return VEHICLE_CAMERA_CONFIG
