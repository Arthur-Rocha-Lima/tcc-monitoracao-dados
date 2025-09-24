package monitoracaodados

import (
	"fmt"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

type MetricData struct {
	System  SystemMetrics  `json:"system"`
	Memory  MemoryMetrics  `json:"memory"`
	CPU     CPUMetrics     `json:"cpu"`
	Disk    DiskMetrics    `json:"disk"`
	Network NetworkMetrics `json:"network"`
}

type SystemMetrics struct {
	Hostname   string `json:"hostname"`
	Platform   string `json:"platform"`
	OS         string `json:"os"`
	KernelArch string `json:"architecture"`
	GoVersion  string `json:"go_version"`
	Uptime     string `json:"uptime"`
	Timestamp  string `json:"timestamp"`
}

type MemoryMetrics struct {
	TotalMB     uint64  `json:"total_mb"`
	UsedMB      uint64  `json:"used_mb"`
	FreeMB      uint64  `json:"free_mb"`
	UsedPercent float64 `json:"used_percent"`
	Timestamp   string  `json:"timestamp"`
}

type CPUMetrics struct {
	Cores        int32   `json:"cores"`
	UsagePercent float64 `json:"usage_percent"`
	Timestamp    string  `json:"timestamp"`
}

type DiskMetrics struct {
	TotalGB     uint64  `json:"total_gb"`
	UsedGB      uint64  `json:"used_gb"`
	FreeGB      uint64  `json:"free_gb"`
	UsedPercent float64 `json:"used_percent"`
	Timestamp   string  `json:"timestamp"`
}

type NetworkMetrics struct {
	BytesSent   uint64 `json:"bytes_sent"`
	BytesRecv   uint64 `json:"bytes_recv"`
	PacketsSent uint64 `json:"packets_sent"`
	PacketsRecv uint64 `json:"packets_recv"`
	Timestamp   string `json:"timestamp"`
}

var (
	cachedMetrics     *MetricData
	cachedMetricsTime time.Time
	metricsMutex      sync.RWMutex
	cacheDuration     = 100 * time.Millisecond
)

func SetCacheDuration(duration time.Duration) {
	metricsMutex.Lock()
	defer metricsMutex.Unlock()
	cacheDuration = duration
}

func GetMetricsWithCache() (*MetricData, error) {
	metricsMutex.RLock()
	cached := cachedMetrics
	cachedTime := cachedMetricsTime
	metricsMutex.RUnlock()

	if cached != nil && time.Since(cachedTime) < cacheDuration {
		return cached, nil
	}

	newMetrics, err := collectMetrics()
	if err != nil {
		if cached != nil {
			return cached, nil
		}
		return nil, err
	}

	metricsMutex.Lock()
	cachedMetrics = newMetrics
	cachedMetricsTime = time.Now()
	metricsMutex.Unlock()

	return newMetrics, nil
}

func GetMetrics() (*MetricData, error) {
	return GetMetricsWithCache()
}
func collectMetrics() (*MetricData, error) {
	var metricData MetricData
	now := time.Now().Format(time.RFC3339Nano)

	hostInfo, err := host.Info()
	if err != nil {
		return nil, fmt.Errorf("falha ao obter info do host: %v", err)
	}
	uptimeDuration := time.Duration(hostInfo.Uptime) * time.Second
	metricData.System = SystemMetrics{
		Hostname:   hostInfo.Hostname,
		Platform:   hostInfo.Platform,
		OS:         hostInfo.OS,
		KernelArch: hostInfo.KernelArch,
		GoVersion:  "go1.23.12",
		Uptime:     uptimeDuration.String(),
		Timestamp:  now,
	}

	memInfo, err := mem.VirtualMemory()
	if err != nil {
		return nil, fmt.Errorf("falha ao obter info da memoria: %v", err)
	}
	metricData.Memory = MemoryMetrics{
		TotalMB:     memInfo.Total / 1024 / 1024,
		UsedMB:      memInfo.Used / 1024 / 1024,
		FreeMB:      memInfo.Free / 1024 / 1024,
		UsedPercent: memInfo.UsedPercent,
		Timestamp:   now,
	}

	cpuInfo, err := cpu.Info()
	if err != nil {
		return nil, fmt.Errorf("falha ao obter info da cpu: %v", err)
	}
	cpuPercent, err := cpu.Percent(0, false)
	if err != nil {
		return nil, fmt.Errorf("falha ao obter porcentagem da cpu: %v", err)
	}
	metricData.CPU = CPUMetrics{
		Cores:        cpuInfo[0].Cores,
		UsagePercent: cpuPercent[0],
		Timestamp:    now,
	}

	diskInfo, err := disk.Usage("/")
	if err != nil {
		return nil, fmt.Errorf("falha ao obter info do disco: %v", err)
	}
	metricData.Disk = DiskMetrics{
		TotalGB:     diskInfo.Total / 1024 / 1024 / 1024,
		UsedGB:      diskInfo.Used / 1024 / 1024 / 1024,
		FreeGB:      diskInfo.Free / 1024 / 1024 / 1024,
		UsedPercent: diskInfo.UsedPercent,
		Timestamp:   now,
	}

	netInfo, err := net.IOCounters(false)
	if err != nil {
		return nil, fmt.Errorf("falha ao obter info da rede: %v", err)
	}
	metricData.Network = NetworkMetrics{
		BytesSent:   netInfo[0].BytesSent,
		BytesRecv:   netInfo[0].BytesRecv,
		PacketsSent: netInfo[0].PacketsSent,
		PacketsRecv: netInfo[0].PacketsRecv,
		Timestamp:   now,
	}

	return &metricData, nil
}

func GetCacheInfo() (time.Time, time.Duration) {
	metricsMutex.RLock()
	defer metricsMutex.RUnlock()
	return cachedMetricsTime, cacheDuration
}

func ClearCache() {
	metricsMutex.Lock()
	defer metricsMutex.Unlock()
	cachedMetrics = nil
	cachedMetricsTime = time.Time{}
}
