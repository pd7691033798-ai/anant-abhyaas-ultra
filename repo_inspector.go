package main

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
)

type WhatsAppCommandRule struct {
	Command      string `json:"command"`
	ExpectedType string `json:"expected_type"`
	MockReply    string `json:"mock_reply"`
}

type LogicScanResult struct {
	Repo             string                `json:"repo"`
	DetectedLanguage string                `json:"detected_language"`
	HasWhatsAppLogic bool                  `json:"has_whatsapp_logic"`
	Commands         []WhatsAppCommandRule `json:"commands"`
	UserScreens      []string              `json:"user_screens"`
	AdminScreens     []string              `json:"admin_screens"`
}

// 1. रिपॉजिटरी की भाषा और लॉजिक स्कैन करना
func InspectRepoLogicHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req struct {
		RepoName string `json:"repo_name"`
		CodeText string `json:"code_text"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	result := LogicScanResult{
		Repo:             req.RepoName,
		DetectedLanguage: detectStack(req.CodeText),
		HasWhatsAppLogic: strings.Contains(req.CodeText, "whatsapp") || strings.Contains(req.CodeText, "messages") || strings.Contains(req.CodeText, "webhook"),
		Commands:         extractCommands(req.CodeText),
		UserScreens:      []string{"Main Dashboard", "Task Screen", "Profile View"},
		AdminScreens:     []string{"Analytics Panel", "User Management", "Webhook Logs"},
	}

	json.NewEncoder(w).Encode(result)
}

// 2. WhatsApp डेमो चैट सिम्युलेटर
func WhatsAppDemoChatHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req struct {
		UserMessage string `json:"user_message"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	reply := "डिफ़ॉल्ट उत्तर: कमांड प्राप्त हुई।"
	msg := strings.ToUpper(strings.TrimSpace(req.UserMessage))

	switch {
	case strings.Contains(msg, "START") || strings.Contains(msg, "HI"):
		reply = "नमस्ते! अनंत अभ्यास सिस्टम सक्रिय है। टास्क शुरू करने हेतु 'SCAN' लिखें।"
	case strings.Contains(msg, "SCAN"):
		reply = "कैमरा मॉड्यूल सक्रिय: कृपया कार्य की फ़ोटो भेजें।"
	case strings.Contains(msg, "STATUS"):
		reply = "सिस्टम स्थिति: सभी बैकएंड इंजन और सैंडबॉक्स सामान्य रूप से कार्यरत हैं।"
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":     "SUCCESS",
		"user_sent":  req.UserMessage,
		"bot_reply":  reply,
		"dispatched": true,
	})
}

func detectStack(code string) string {
	if strings.Contains(code, "package ") && strings.Contains(code, "func ") {
		return "Go (Golang)"
	}
	if strings.Contains(code, "import 'package:flutter") {
		return "Flutter (Dart)"
	}
	return "React / Node.js"
}

func extractCommands(code string) []WhatsAppCommandRule {
	re := regexp.MustCompile(`(?i)(case\s+"([^"]+)"|if\s+.*"([^"]+)")`)
	matches := re.FindAllStringSubmatch(code, -1)

	rules := make([]WhatsAppCommandRule, 0)
	for _, m := range matches {
		val := m[2]
		if val == "" {
			val = m[3]
		}
		if len(val) > 1 && len(val) < 20 {
			rules = append(rules, WhatsAppCommandRule{
				Command:      val,
				ExpectedType: "TEXT_COMMAND",
				MockReply:    "स्वतः पहचाना गया लॉजिक उत्तर",
			})
		}
	}
	return rules
}
