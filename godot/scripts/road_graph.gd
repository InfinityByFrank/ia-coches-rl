## Grafo de calles: que celdas del GridMap son carretera y como se conectan.
## Sirve para elegir metas y calcular la ruta mas corta (BFS) hasta ellas.
class_name RoadGraph
extends Node

const ROAD_ITEMS := [0, 1, 2, 3, 4, 5]   # road_* en la MeshLibrary
const CELL := 2.0                         # metros por celda
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var cells: Dictionary = {}   # Vector2i -> true


func _ready() -> void:
	add_to_group("roadgraph")
	var gm: GridMap = get_node("../City/GridMap")
	for c in gm.get_used_cells():
		if gm.get_cell_item(c) in ROAD_ITEMS:
			cells[Vector2i(c.x, c.z)] = true


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.1, (c.y + 0.5) * CELL)


## BFS desde `start`. Devuelve [dist, first]:
##   dist[celda]  = numero de celdas hasta llegar a ella
##   first[celda] = primera celda del camino (vecina de `start`) para llegar a ella
func bfs(start: Vector2i) -> Array:
	var dist := {start: 0}
	var first := {}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				first[n] = n if c == start else first[c]
				queue.append(n)
	return [dist, first]
