package domain

import "errors"

var (
	ErrTrainerClientNotFound   = errors.New("trainer client not found")
	ErrTrainerProfileNotFound  = errors.New("trainer profile not found")
	ErrTrainerPhotoNotFound    = errors.New("trainer photo not found")
	ErrTrainingProgramNotFound = errors.New("training program not found")
	ErrTrainerCommentNotFound  = errors.New("trainer comment not found")
	ErrAlreadyClient           = errors.New("already a client of this trainer")
)
