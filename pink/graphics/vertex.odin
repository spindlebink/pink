package pink_graphics

Vertex :: struct {
	position: [3]f32,
	color: [3]f32,
}

VERTICES :: []Vertex{
	Vertex{
		position = {0.0, 0.5, 0.0},
		color = {1.0, 0.0, 0.0},
	},
	Vertex{
		position = {-0.5, -0.5, 0.0},
		color = {0.0, 1.0, 0.0},
	},
	Vertex{
		position = {0.5, -0.5, 0.0},
		color = {0.0, 0.0, 1.0},
	},
}

