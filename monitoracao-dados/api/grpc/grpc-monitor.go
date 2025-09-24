package main

import (
	"context"
	"log"
	"net"

	"google.golang.org/grpc"

	proto "monitor/api/grpc/proto"
	monitoracaodados "monitor/metrics"
)

const (
	port = ":50051"
)

type MetricServer struct {
	proto.UnimplementedMetricServiceServer
}

func (s *MetricServer) GetMetrics(ctx context.Context, in *proto.MetricsRequest) (*proto.MetricsResponse, error) {
	metricData, err := monitoracaodados.GetMetrics()
	if err != nil {
		return nil, err
	}
	metrics := &proto.MetricsResponse{
		System: &proto.SystemMetrics{
			Hostname:     metricData.System.Hostname,
			Platform:     metricData.System.Platform,
			Architecture: metricData.System.KernelArch,
			GoVersion:    metricData.System.GoVersion,
			Uptime:       metricData.System.Uptime,
			Timestamp:    metricData.System.Timestamp,
		},
		Memory: &proto.MemoryMetrics{
			TotalMb:     metricData.Memory.TotalMB,
			UsedMb:      metricData.Memory.UsedMB,
			FreeMb:      metricData.Memory.FreeMB,
			UsedPercent: metricData.Memory.UsedPercent,
			Timestamp:   metricData.Memory.Timestamp,
		},
		Cpu: &proto.CPUMetrics{
			Cores:        metricData.CPU.Cores,
			UsagePercent: metricData.CPU.UsagePercent,
			Timestamp:    metricData.CPU.Timestamp,
		},
		Disk: &proto.DiskMetrics{
			TotalGb:     metricData.Disk.TotalGB,
			UsedGb:      metricData.Disk.UsedGB,
			FreeGb:      metricData.Disk.FreeGB,
			UsedPercent: metricData.Disk.UsedPercent,
			Timestamp:   metricData.Disk.Timestamp,
		},
		Network: &proto.NetworkMetrics{
			BytesSent:   metricData.Network.BytesSent,
			BytesRecv:   metricData.Network.BytesRecv,
			PacketsSent: metricData.Network.PacketsSent,
			PacketsRecv: metricData.Network.PacketsRecv,
			Timestamp:   metricData.Network.Timestamp,
		},
	}

	return metrics, nil
}

func main() {
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("falha ao escutar na porta %s: %v", port, err)
	}

	s := grpc.NewServer()

	metricServer := &MetricServer{}
	proto.RegisterMetricServiceServer(s, metricServer)

	if err := s.Serve(lis); err != nil {
		log.Fatalf("falha ao servir: %v", err)
	}
}
