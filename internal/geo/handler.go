package geo

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// RegisterRoutes registers geo (DaData) routes on the given group. If client is nil, routes return empty; otherwise they call DaData (empty key is handled inside the client).
func RegisterRoutes(rg *gin.RouterGroup, client *Client) {
	if client == nil {
		rg.GET("/cities", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"items": []interface{}{}}) })
		rg.GET("/organizations", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"items": []interface{}{}}) })
		return
	}
	rg.GET("/cities", func(c *gin.Context) {
		q := c.Query("q")
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
		items, err := client.SuggestCities(c.Request.Context(), q, limit)
		if err != nil || items == nil {
			c.JSON(http.StatusOK, gin.H{"items": []CitySuggestion{}})
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	})
	rg.GET("/organizations", func(c *gin.Context) {
		q := c.Query("q")
		regionID := c.Query("region_id")
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "15"))
		items, err := client.SuggestOrganizations(c.Request.Context(), q, regionID, limit)
		if err != nil || items == nil {
			c.JSON(http.StatusOK, gin.H{"items": []OrgSuggestion{}})
			return
		}
		c.JSON(http.StatusOK, gin.H{"items": items})
	})
}
