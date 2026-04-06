package xp

// DeltaXPFromVolume matches Flutter [XpCalculationService] with default coefficients.
func DeltaXPFromVolume(totalVolumeKg float64) int {
	return DeltaFromVolume(totalVolumeKg, DefaultCurve())
}
