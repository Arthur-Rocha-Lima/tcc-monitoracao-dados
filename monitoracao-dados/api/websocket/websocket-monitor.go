package main

import (
	"encoding/json"
	"log"
	"net/http"
	"runtime"
	"sync/atomic"
	"time"

	monitoracaodados "monitor/metrics"

	"github.com/gorilla/websocket"
)

var (
	messageCounter   uint64
	startTime        = time.Now()
	totalConnections uint64
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  65536,
	WriteBufferSize: 65536,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Erro ao fazer upgrade da conexão: %v", err)
		return
	}
	defer conn.Close()

	atomic.AddUint64(&totalConnections, 1)
	connID := atomic.LoadUint64(&totalConnections)

	conn.SetReadLimit(1048576)

	log.Printf("Nova conexão WebSocket estabelecida (ID: %d)", connID)

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Erro de leitura WebSocket: %v", err)
			}
			break
		}

		messageStr := string(message)
		msgCount := atomic.AddUint64(&messageCounter, 1)

		responseData := map[string]interface{}{
			"message_id":       msgCount,
			"server_timestamp": time.Now().UnixNano() / 1000000,
			"client_message":   messageStr,
			"connection_id":    connID,
		}

		if msgCount%50 == 0 || messageStr == "STATS" {
			if metrics, err := monitoracaodados.GetMetrics(); err == nil && metrics != nil {
				responseData["system"] = metrics
			}

			if messageStr == "STATS" {
				responseData["server_stats"] = map[string]interface{}{
					"total_messages": msgCount,
					"uptime_seconds": time.Since(startTime).Seconds(),
					"connections":    atomic.LoadUint64(&totalConnections),
					"go_routines":    runtime.NumGoroutine(),
				}
			}
		}

		jsonData, err := json.Marshal(responseData)
		if err != nil {
			log.Printf("Erro ao codificar JSON: %v", err)
			errorMsg := map[string]interface{}{
				"error": "Falha ao codificar JSON",
			}
			jsonError, _ := json.Marshal(errorMsg)
			conn.WriteMessage(websocket.TextMessage, jsonError)
			continue
		}

		if err := conn.WriteMessage(websocket.TextMessage, jsonData); err != nil {
			log.Printf("Erro ao enviar mensagem via WebSocket: %v", err)
			break
		}
	}

	log.Printf("Conexão WebSocket fechada (ID: %d)", connID)
}

func handleStats(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	stats := map[string]interface{}{
		"total_messages":    atomic.LoadUint64(&messageCounter),
		"uptime_seconds":    time.Since(startTime).Seconds(),
		"total_connections": atomic.LoadUint64(&totalConnections),
		"go_routines":       runtime.NumGoroutine(),
		"server_time":       time.Now().Format(time.RFC3339),
	}

	if metrics, err := monitoracaodados.GetMetrics(); err == nil && metrics != nil {
		stats["system"] = metrics
	}

	json.NewEncoder(w).Encode(stats)
}

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())

	http.HandleFunc("/ws", handleWebSocket)
	http.HandleFunc("/stats", handleStats)

	log.Fatal(http.ListenAndServe(":8081", nil))
}
