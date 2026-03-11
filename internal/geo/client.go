package geo

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/rs/zerolog/log"
)

const (
	daDataAddressURL = "https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/address"
	daDataPartyURL   = "https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/party"
)

// Client calls DaData Suggest API.
type Client struct {
	APIKey    string
	SecretKey string
	Client    *http.Client
}

// NewClient creates a geo client. If APIKey is empty, methods return empty results.
func NewClient(apiKey, secretKey string) *Client {
	return &Client{
		APIKey:    apiKey,
		SecretKey: secretKey,
		Client:    http.DefaultClient,
	}
}

// CitySuggestion is a city suggest item.
type CitySuggestion struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	RegionID string `json:"region_id,omitempty"`
}

// SuggestCities returns city suggestions for the query (Russia).
// Uses DaData address suggest with from_bound/to_bound=city.
func (c *Client) SuggestCities(ctx context.Context, q string, limit int) ([]CitySuggestion, error) {
	if c.APIKey == "" || q == "" {
		log.Info().Str("api", "dadata").Str("method", "suggest/address").Str("query", q).Bool("no_key", c.APIKey == "").Msg("dadata skip (no key or empty query)")
		return nil, nil
	}
	if limit <= 0 {
		limit = 10
	}
	body := map[string]interface{}{
		"query": q,
		"count": limit,
		"from_bound": map[string]string{"value": "city"},
		"to_bound":   map[string]string{"value": "city"},
	}
	return c.suggestCities(ctx, body)
}

func (c *Client) suggestCities(ctx context.Context, body map[string]interface{}) ([]CitySuggestion, error) {
	q, _ := body["query"].(string)
	limit, _ := body["count"].(int)
	log.Info().
		Str("api", "dadata").
		Str("method", "suggest/address").
		Str("query", q).
		Int("limit", limit).
		Msg("dadata request")
	jsonBody, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, daDataAddressURL, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Token "+c.APIKey)
	if c.SecretKey != "" {
		req.Header.Set("X-Secret", c.SecretKey)
	}
	resp, err := c.Client.Do(req)
	if err != nil {
		log.Info().Str("api", "dadata").Str("method", "suggest/address").Err(err).Msg("dadata request failed")
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		log.Info().Str("api", "dadata").Str("method", "suggest/address").Int("status", resp.StatusCode).Msg("dadata response")
		return nil, nil
	}
	var out struct {
		Suggestions []struct {
			Value string `json:"value"`
			Data  struct {
				City        string `json:"city"`
				Region      string `json:"region"`
				CityKladrID string `json:"city_kladr_id"`
				RegionKladr string `json:"region_kladr_id"`
			} `json:"data"`
		} `json:"suggestions"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	list := make([]CitySuggestion, 0, len(out.Suggestions))
	seen := make(map[string]bool)
	for _, s := range out.Suggestions {
		name := s.Data.City
		if name == "" {
			name = s.Data.Region
		}
		if name == "" {
			name = s.Value
		}
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		id := s.Data.CityKladrID
		if id == "" {
			id = s.Data.RegionKladr
		}
		if id == "" {
			id = name
		}
		list = append(list, CitySuggestion{
			ID:       id,
			Name:     name,
			RegionID: s.Data.RegionKladr,
		})
	}
	log.Info().Str("api", "dadata").Str("method", "suggest/address").Int("status", 200).Int("count", len(list)).Msg("dadata response")
	return list, nil
}

// OrgSuggestion is an organization (e.g. gym) suggest item.
type OrgSuggestion struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Address  string  `json:"address,omitempty"`
	RegionID string  `json:"region_id,omitempty"`
	Lat      float64 `json:"lat,omitempty"`
	Lon      float64 `json:"lon,omitempty"`
}

// SuggestOrganizations returns organization suggestions (e.g. gyms) for query in the given region.
// Uses DaData party suggest. regionKladrID is KLADR code (e.g. "77" for Moscow).
func (c *Client) SuggestOrganizations(ctx context.Context, q, regionKladrID string, limit int) ([]OrgSuggestion, error) {
	if c.APIKey == "" || q == "" {
		log.Info().Str("api", "dadata").Str("method", "suggest/party").Str("query", q).Bool("no_key", c.APIKey == "").Msg("dadata skip (no key or empty query)")
		return nil, nil
	}
	if limit <= 0 {
		limit = 15
	}
	body := map[string]interface{}{
		"query": q,
		"count": limit,
	}
	if regionKladrID != "" {
		body["locations"] = []map[string]string{{"kladr_id": regionKladrID}}
	}
	log.Info().
		Str("api", "dadata").
		Str("method", "suggest/party").
		Str("query", q).
		Str("region_kladr_id", regionKladrID).
		Int("limit", limit).
		Msg("dadata request")
	jsonBody, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, daDataPartyURL, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Token "+c.APIKey)
	if c.SecretKey != "" {
		req.Header.Set("X-Secret", c.SecretKey)
	}
	resp, err := c.Client.Do(req)
	if err != nil {
		log.Info().Str("api", "dadata").Str("method", "suggest/party").Err(err).Msg("dadata request failed")
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		log.Info().Str("api", "dadata").Str("method", "suggest/party").Int("status", resp.StatusCode).Msg("dadata response")
		return nil, nil
	}
	var out struct {
		Suggestions []struct {
			Value string `json:"value"`
			Data  struct {
				INN  string `json:"inn"`
				KPP  string `json:"kpp"`
				Name struct {
					Short string `json:"short"`
					Full  string `json:"full"`
				} `json:"name"`
				Address struct {
					Value string `json:"value"`
					Data  *struct {
						GeoLat string `json:"geo_lat"`
						GeoLon string `json:"geo_lon"`
					} `json:"data"`
				} `json:"address"`
			} `json:"data"`
		} `json:"suggestions"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	list := make([]OrgSuggestion, 0, len(out.Suggestions))
	for _, s := range out.Suggestions {
		name := s.Data.Name.Short
		if name == "" {
			name = s.Data.Name.Full
		}
		if name == "" {
			name = s.Value
		}
		id := s.Data.INN
		if id == "" {
			id = s.Data.KPP
		}
		if id == "" {
			id = name
		}
		var lat, lon float64
		if s.Data.Address.Data != nil {
			lat, _ = strconv.ParseFloat(s.Data.Address.Data.GeoLat, 64)
			lon, _ = strconv.ParseFloat(s.Data.Address.Data.GeoLon, 64)
		}
		list = append(list, OrgSuggestion{
			ID:      id,
			Name:    name,
			Address: s.Data.Address.Value,
			Lat:     lat,
			Lon:     lon,
		})
	}
	log.Info().Str("api", "dadata").Str("method", "suggest/party").Int("status", 200).Int("count", len(list)).Msg("dadata response")
	return list, nil
}
