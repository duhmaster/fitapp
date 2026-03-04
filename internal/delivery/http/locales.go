package http

import (
	"embed"
	"io/fs"
	"net/http"
	"path"
	"strings"

	"github.com/gin-gonic/gin"
)

//go:embed locales/*.json
var localeFS embed.FS

func listLocales(c *gin.Context) {
	entries, err := fs.Glob(localeFS, "locales/*.json")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list locales"})
		return
	}
	locales := make([]string, 0, len(entries))
	for _, e := range entries {
		base := path.Base(e)
		lang := strings.TrimSuffix(base, ".json")
		if lang != "" {
			locales = append(locales, lang)
		}
	}
	c.JSON(http.StatusOK, gin.H{"locales": locales})
}

func getLocale(c *gin.Context) {
	lang := c.Param("lang")
	if lang == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "lang required"})
		return
	}
	// Restrict to alphanumeric to avoid path traversal
	for _, r := range lang {
		if (r < 'a' || r > 'z') && (r < 'A' || r > 'Z') && (r < '0' || r > '9') && r != '-' && r != '_' {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid lang"})
			return
		}
	}
	name := "locales/" + lang + ".json"
	data, err := fs.ReadFile(localeFS, name)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "locale not found"})
		return
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", data)
}
