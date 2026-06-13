---
name: ejecuta-iris
description: >-
  Limpia, descarga dependencias y ejecuta la app Flutter de Iris en el dispositivo por defecto.
---

# Ejecuta Iris

## Overview
Esta skill automatiza el flujo de compilación en limpio para la aplicación Iris. Realiza tres pasos secuenciales: limpia la build previa, resuelve las dependencias y lanza la aplicación inyectando la API KEY necesaria para el modelo en la nube.

## Workflow

### 1. Reconstrucción Limpia
- Navega al directorio de la aplicación: `D:/proyectos/ProyectoIris/iris_app`
- Ejecuta de forma secuencial y en una sola línea de comandos:

### 2. Monitoreo
- Avisa al usuario que el proceso se ha lanzado en segundo plano.
- Mantén la tarea ejecutándose para permitir el uso posterior de Hot Reload (`r`).
