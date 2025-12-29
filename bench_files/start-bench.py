#!/usr/bin/env python3

import os
import socket
import platform
import subprocess
import time
import json
import logging
import sys
from typing import Dict, Optional

# --- Configurar logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('start-bench.log', mode='a')
    ]
)
logger = logging.getLogger(__name__)

# --- Detectar sistema ---
system_platform = platform.system()
logger.info("Sistema detectado: %s", system_platform)

# --- Rangos de puertos por servicio ---
PORT_RANGES = {
    'redis_cache': (13000, 13099),
    'redis_queue': (11000, 11099),
    'redis_socketio': (12000, 12099),
    'socketio': (9000, 9099),
    'webserver': (8000, 8099),
    'file_watcher': (6700, 6799)
}


class PortManager:
    """Gestor de puertos para servicios Frappe"""

    def __init__(self):
        self.allocated_ports = set()

    def is_port_available(self, port: int, host: str = '127.0.0.1') -> bool:
        """Verifica si un puerto está disponible"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                result = sock.connect_ex((host, port))
                return result != 0
        except Exception as e:
            logger.warning("Error verificando puerto %s: %s", port, e)
            return False

    def find_available_port(self, service: str,
                            preferred_port: Optional[int] = None) -> int:
        """Encuentra un puerto disponible para un servicio específico"""
        if service not in PORT_RANGES:
            raise ValueError(f"Servicio desconocido: {service}")

        start_port, end_port = PORT_RANGES[service]

        # Intentar puerto preferido primero si está especificado y en rango
        if preferred_port and start_port <= preferred_port <= end_port:
            available = self.is_port_available(preferred_port)
            not_allocated = preferred_port not in self.allocated_ports
            if available and not_allocated:
                self.allocated_ports.add(preferred_port)
                logger.info("Puerto preferido %s disponible para %s",
                            preferred_port, service)
                return preferred_port

        # Buscar puerto disponible en el rango
        for port in range(start_port, end_port + 1):
            available = self.is_port_available(port)
            not_allocated = port not in self.allocated_ports
            if not_allocated and available:
                self.allocated_ports.add(port)
                logger.info("Puerto %s asignado para %s", port, service)
                return port

        error_msg = (f"No se encontraron puertos disponibles para {service} "
                     f"en rango {start_port}-{end_port}")
        raise RuntimeError(error_msg)

    def kill_port(self, port: int) -> bool:
        """Termina procesos que usan un puerto específico"""
        try:
            logger.info("Intentando liberar puerto %s", port)

            # Intentar cerrar Redis con comando shutdown
            try:
                cmd = ["redis-cli", "-h", "127.0.0.1", "-p", str(port),
                       "shutdown"]
                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=5, check=True
                )
                if result.returncode == 0:
                    logger.info(("Redis en puerto %s "
                                "cerrado correctamente"), port)
                    time.sleep(1)
                    return True
            except subprocess.TimeoutExpired:
                logger.warning("Timeout cerrando Redis en puerto %s", port)
            except Exception as e:
                logger.warning(
                    "Error cerrando Redis en puerto %s: %s", port, e
                    )

            # Forzar cierre según el sistema operativo
            if system_platform == "Linux":
                result = subprocess.run(
                    ["fuser", f"{port}/tcp", "-k"],
                    capture_output=True, text=True, check=True
                )
                if result.returncode == 0:
                    logger.info("Proceso en puerto %s terminado (Linux)", port)
                    time.sleep(1)
                    return True
            else:
                # macOS y otros sistemas Unix
                cmd = (f"lsof -i tcp:{port} | grep -v PID | "
                       f"awk '{{print $2}}' | xargs kill")
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, check=True
                )
                if result.returncode == 0:
                    logger.info("Proceso en puerto %s terminado (Unix)", port)
                    time.sleep(1)
                    return True

            return False
        except Exception as e:
            logger.error("Error liberando puerto %s: %s", port, e)
            return False


def validate_environment() -> bool:
    """Valida que el entorno sea correcto para ejecutar el script"""
    required_files = [
        "./config/redis_cache.conf",
        "./config/redis_queue.conf",
        "./sites/common_site_config.json"
    ]

    for file_path in required_files:
        if not os.path.exists(file_path):
            logger.error("Archivo requerido no encontrado: %s", file_path)
            return False

    # Verificar que estamos en el directorio correcto (raíz de bench)
    if not os.path.exists("./apps") or not os.path.exists("./sites"):
        logger.error("Este script debe ejecutarse desde la raíz del "
                     "directorio bench")
        return False

    return True


def read_current_ports() -> Dict[str, int]:
    """Lee los puertos actuales de los archivos de configuración"""
    ports = {}

    try:
        # Redis cache port
        with open("./config/redis_cache.conf", encoding="utf-8") as f:
            for line in f:
                if line.startswith("port"):
                    ports['redis_cache'] = int(line.split()[1])
                    break
    except Exception as e:
        logger.warning("Error leyendo redis_cache.conf: %s", e)

    try:
        # Redis queue port
        with open("./config/redis_queue.conf", encoding="utf-8") as f:
            for line in f:
                if line.startswith("port"):
                    ports['redis_queue'] = int(line.split()[1])
                    break
    except Exception as e:
        logger.warning("Error leyendo redis_queue.conf: %s", e)

    try:
        # Ports from common_site_config.json
        with open("./sites/common_site_config.json", encoding="utf-8") as f:
            config = json.load(f)
            ports['webserver'] = config.get("webserver_port", 8000)
            ports['socketio'] = config.get("socketio_port", 9000)
            ports['file_watcher'] = config.get("file_watcher_port", 6787)

            # Extract Redis ports from Redis URLs
            redis_cache_url = config.get("redis_cache", "")
            redis_queue_url = config.get("redis_queue", "")

            if redis_cache_url and ":" in redis_cache_url:
                try:
                    ports['redis_cache'] = int(redis_cache_url.split(":")[-1])
                except ValueError:
                    pass

            if redis_queue_url and ":" in redis_queue_url:
                try:
                    ports['redis_queue'] = int(redis_queue_url.split(":")[-1])
                except ValueError:
                    pass
    except Exception as e:
        logger.warning("Error leyendo common_site_config.json: %s", e)

    return ports


def update_config_files(ports: Dict[str, int]) -> bool:
    """Actualiza los archivos de configuración con los nuevos puertos"""
    try:
        # Actualizar redis_cache.conf
        if 'redis_cache' in ports:
            update_redis_config("./config/redis_cache.conf",
                                ports['redis_cache'])

        # Actualizar redis_queue.conf
        if 'redis_queue' in ports:
            update_redis_config("./config/redis_queue.conf",
                                ports['redis_queue'])

        # Actualizar common_site_config.json
        update_common_site_config(ports)

        return True
    except Exception as e:
        logger.error("Error actualizando archivos de configuración: %s", e)
        return False


def update_redis_config(config_path: str, port: int) -> None:
    """Actualiza el puerto en un archivo de configuración de Redis"""
    try:
        with open(config_path, 'r', encoding="utf-8") as f:
            lines = f.readlines()

        with open(config_path, 'w', encoding="utf-8") as f:
            for line in lines:
                if line.startswith('port'):
                    f.write(f'port {port}\n')
                    logger.info("Puerto actualizado a %d en %s", port, config_path)
                else:
                    f.write(line)
    except Exception as e:
        logger.error("Error actualizando %s: %s", config_path, e)
        raise


def update_common_site_config(ports: Dict[str, int]) -> None:
    """Actualiza el archivo common_site_config.json con los nuevos puertos"""
    try:
        with open("./sites/common_site_config.json", 'r', encoding="utf-8") as f:
            config = json.load(f)

        # Actualizar puertos
        if 'webserver' in ports:
            config['webserver_port'] = ports['webserver']
        if 'socketio' in ports:
            config['socketio_port'] = ports['socketio']
        if 'file_watcher' in ports:
            config['file_watcher_port'] = ports['file_watcher']
        if 'redis_cache' in ports:
            config['redis_cache'] = f"redis://127.0.0.1:{ports['redis_cache']}"
            redis_cache_url = f"redis://127.0.0.1:{ports['redis_cache']}"
            config['redis_socketio'] = redis_cache_url
        if 'redis_queue' in ports:
            config['redis_queue'] = f"redis://127.0.0.1:{ports['redis_queue']}"

        with open("./sites/common_site_config.json", 'w', encoding="utf-8") as f:
            json.dump(config, f, indent=1)

        logger.info("common_site_config.json actualizado correctamente")
    except Exception as e:
        logger.error("Error actualizando common_site_config.json: %s", e)
        raise


def main(selected_site: str | None):
    """Función principal del script"""
    try:
        logger.info("=== Iniciando start-bench.py ===")

        # Validar entorno
        if not validate_environment():
            logger.error("Validación del entorno falló")
            sys.exit(1)

        # Crear gestor de puertos
        port_manager = PortManager()

        # Leer puertos actuales
        current_ports = read_current_ports()
        logger.info("Puertos actuales: %s", current_ports)

        # Cerrar procesos en puertos actuales
        for service, port in current_ports.items():
            if port:
                port_manager.kill_port(port)

        # Buscar nuevos puertos disponibles
        new_ports = {}
        services = ['redis_cache', 'redis_queue', 'socketio', 'webserver',
                    'file_watcher']

        for service in services:
            try:
                preferred_port = current_ports.get(service)
                new_port = port_manager.find_available_port(
                    service, preferred_port)
                new_ports[service] = new_port
            except RuntimeError as e:
                logger.error("Error asignando puerto para %s: %s", service, e)
                sys.exit(1)

        logger.info("Nuevos puertos asignados: %s", new_ports)

        # Actualizar archivos de configuración
        if not update_config_files(new_ports):
            logger.error("Error actualizando configuraciones")
            sys.exit(1)

        # Iniciar servicios Redis
        logger.info("Iniciando servicios Redis...")
        redis_processes = []
        redis_configs = [
            "config/redis_cache.conf",
            "config/redis_queue.conf"
        ]

        for conf in redis_configs:
            if os.path.exists(conf):
                logger.info("Iniciando %s...", conf)
                try:
                    p = subprocess.Popen(
                        ["redis-server", conf],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE
                    )
                    redis_processes.append(p)
                    time.sleep(1)  # Pequeña pausa entre inicios
                except Exception as e:
                    logger.error("Error iniciando %s: %s", conf, e)
            else:
                logger.warning("Archivo %s no existe", conf)

        # Esperar que Redis arranque
        time.sleep(3)

        # Verificar que Redis esté funcionando
        for service in ['redis_cache', 'redis_queue']:
            if service in new_ports:
                port = new_ports[service]
                try:
                    cmd = ["redis-cli", "-h", "127.0.0.1", "-p", str(port),
                           "ping"]
                    result = subprocess.run(
                        cmd, capture_output=True, text=True, timeout=5, check=True
                    )
                    if result.returncode == 0 and "PONG" in result.stdout:
                        logger.info(
                            "Redis %s funcionando en puerto %d", service, port
                            )
                    else:
                        logger.warning(
                            "Redis %s no responde en puerto %d", service, port
                            )
                except Exception as e:
                    logger.warning("Error verificando Redis %s: %s", service, e)

        # Iniciar Frappe
        frappe_port = new_ports['webserver']
        logger.info("Iniciando Frappe en puerto %d...", frappe_port)

        # Buscar el sitio por defecto
        default_site = selected_site
        print(default_site)
        try:
            with open("./sites/common_site_config.json", encoding='utf-8') as f:
                config = json.load(f)
                if not selected_site:
                    default_site = config.get("default_site", default_site)
                print(default_site)
                if not default_site:
                    # Si no hay sitio por defecto, buscar el primero disponible
                    sites = [d for d in os.listdir("./sites") 
                            if os.path.isdir(f"./sites/{d}") and d != "assets"]
                    if sites:
                        default_site = sites[0]
                        logger.info("Usando sitio: %s", default_site)
        except Exception as e:
            logger.warning("Error determinando sitio por defecto: %s", e)

        # Ejecutar comando bench serve
        cmd = ["bench", "--site", default_site, "serve", "--port", str(frappe_port)]
        logger.info("Ejecutando: %s", ' '.join(cmd))

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            logger.error("Error ejecutando bench serve: %s", e)
            sys.exit(1)
        except KeyboardInterrupt:
            logger.info("Recibida señal de interrupción, cerrando servicios...")
            for p in redis_processes:
                try:
                    p.terminate()
                    p.wait(timeout=5)
                except Exception as e:
                    logger.error("Error cerrando proceso Redis: %s", e)
                    p.kill()
            sys.exit(0)

    except Exception as e:
        logger.error("Error inesperado: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    try:
        with open("./sites/common_site_config.json", encoding='utf-8') as f:
            config = json.load(f)
            # Si no hay sitio por defecto, buscar el primero disponible
            sites = [d for d in os.listdir("./sites")
                     if os.path.isdir(f"./sites/{d}") and d != "assets"]
            f_sites = []
            for s in sites:
                site = str(sites.index(s)) + ". " + s
                f_sites.append(site)
        print("SITIOS DISPONIBLES")
        print("\n".join(f_sites))
        SITE = input("Que sitio quieres desplegar?: \n")
        try:
            if SITE == "exit":
                exit()
            SITE = int(SITE)
            SITE = sites[SITE]
            if not SITE:
                raise ValueError("Non existent site")
        except ValueError:
            SITE = None    
        main(SITE)
    except IOError:
        print("Config file does not exist")
