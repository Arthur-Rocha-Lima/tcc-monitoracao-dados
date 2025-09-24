package main

import (
	"encoding/json"
	"log"
	"net/http"

	monitoracaodados "monitor/metrics"
)

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	metricData, err := monitoracaodados.GetMetrics()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(metricData); err != nil {
		http.Error(w, "Falha ao codificar JSON", http.StatusInternalServerError)
	}
}

func main() {
	http.HandleFunc("/metrics", metricsHandler)
	port := ":8080"
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Falha ao iniciar o servidor: %v", err)
	}
}
