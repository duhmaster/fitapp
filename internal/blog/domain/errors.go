package domain

import "errors"

var (
	ErrBlogPostNotFound   = errors.New("blog post not found")
	ErrBlogPostPhotoNotFound = errors.New("blog post photo not found")
	ErrTagNotFound        = errors.New("tag not found")
	ErrTagExists          = errors.New("tag already exists")
)
