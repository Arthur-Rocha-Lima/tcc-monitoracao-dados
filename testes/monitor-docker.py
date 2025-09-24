#!/usr/bin/env python3

import subprocess
import time
import argparse

def get_docker_stats_simple(container_name):
    try:
        cmd = ["docker", "stats", container_name, "--no-stream", "--format", "{{.CPUPerc}} {{.MemUsage}}"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            output = result.stdout.strip().split()
            if len(output) >= 3:
                return output[0], output[1]
        return None, None
    except:
        return None, None

def parse_memory(mem_str):
    if not mem_str:
        return 0.0
    
    mem_str = mem_str.lower()
    
    if 'gib' in mem_str:
        return float(mem_str.replace('gib', '')) * 1024
    elif 'mib' in mem_str:
        return float(mem_str.replace('mib', ''))
    elif 'kib' in mem_str:
        return float(mem_str.replace('kib', '')) / 1024
    else:
        try:
            return float(mem_str)
        except:
            return 0.0

def main_simple():
    parser = argparse.ArgumentParser(description='Monitora CPU% e RAM(MB) de container Docker')
    parser.add_argument('container', help='Nome do container')
    parser.add_argument('--duration', type=int, default=5, help='Duração em minutos')
    
    args = parser.parse_args()
    
    cpu_sum = 0.0
    ram_sum = 0.0
    count = 0
    duration_seconds = args.duration * 60
    
    print(f"Monitorando {args.container} por {args.duration} minutos...")
    
    start_time = time.time()
    while time.time() - start_time < duration_seconds:
        cpu_str, mem_str = get_docker_stats_simple(args.container)
        
        if cpu_str and mem_str:
            try:
                cpu_val = float(cpu_str.replace('%', '').strip())
                cpu_sum += cpu_val
                
                mem_usage_str = mem_str.split('/')[0].strip()
                ram_val = parse_memory(mem_usage_str)
                ram_sum += ram_val
                
                count += 1
                print(f"Amostra {count}: CPU={cpu_val:.1f}%, RAM={ram_val:.1f}MB", end='\r')
                
            except ValueError:
                pass
        
        time.sleep(2)
    
    print("\n" + "="*40)
    if count > 0:
        avg_cpu = cpu_sum / count
        avg_ram = ram_sum / count
        print(f"CPU média: {avg_cpu:.2f}%")
        print(f"RAM média: {avg_ram:.2f} MB")
    else:
        print("Nenhum dado coletado")

if __name__ == "__main__":
    main_simple()