# Iconos de Minimo OS

- `src/`: fuente única de los 45 iconos de línea monocromáticos. Editar estos SVG.
- `animated/`: SVG animados, independientes del conjunto estático.

Las variantes de color (`dark/`, `gray/`, `graydark/`, `white/`) se aplican en tiempo de ejecución mediante `Common/Icon.qml` y `shaders/tint.frag`; no se mantienen copias de los SVG por tono.
