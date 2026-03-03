package domain

import "errors"

var (
	ErrWeightEntryNotFound   = errors.New("weight entry not found")
	ErrBodyFatEntryNotFound  = errors.New("body fat entry not found")
	ErrHealthMetricNotFound  = errors.New("health metric not found")
)
