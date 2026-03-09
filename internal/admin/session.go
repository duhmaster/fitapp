package admin

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const (
	cookieName   = "admin_session"
	cookieMaxAge = 24 * 60 * 60 // 24 hours
)

func setSession(w http.ResponseWriter, username, secret string) {
	exp := time.Now().Add(time.Duration(cookieMaxAge) * time.Second).Unix()
	payload := fmt.Sprintf("%s:%d", username, exp)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	sig := base64.URLEncoding.EncodeToString(mac.Sum(nil))
	value := base64.URLEncoding.EncodeToString([]byte(payload + "." + sig))
	http.SetCookie(w, &http.Cookie{
		Name:     cookieName,
		Value:    value,
		Path:     "/admin",
		MaxAge:   cookieMaxAge,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
}

func clearSession(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     cookieName,
		Value:    "",
		Path:     "/admin",
		MaxAge:   -1,
		HttpOnly: true,
	})
}

func validateSession(r *http.Request, secret string) (username string, ok bool) {
	if secret == "" {
		return "", false
	}
	c, err := r.Cookie(cookieName)
	if err != nil || c.Value == "" {
		return "", false
	}
	dec, err := base64.URLEncoding.DecodeString(c.Value)
	if err != nil {
		return "", false
	}
	parts := strings.SplitN(string(dec), ".", 2)
	if len(parts) != 2 {
		return "", false
	}
	payload, sig := parts[0], parts[1]
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	expectedSig := base64.URLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(sig), []byte(expectedSig)) {
		return "", false
	}
	cols := strings.SplitN(payload, ":", 2)
	if len(cols) != 2 {
		return "", false
	}
	exp, err := strconv.ParseInt(cols[1], 10, 64)
	if err != nil || time.Now().Unix() > exp {
		return "", false
	}
	return cols[0], true
}
