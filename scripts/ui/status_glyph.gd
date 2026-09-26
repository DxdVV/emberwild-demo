class_name StatusGlyph extends RefCounted

const SHIELD: Array[String] = ["1111111","1000001","1001001","1001001","0101010","0111110","0001000"]

static func draw(canvas: CanvasItem, rows: Array[String], at: Vector2, color: Color, pixel: int = 1) -> void:
	for y in rows.size():
		var start := -1
		for x in rows[y].length():
			if rows[y][x]=="1" and start<0: start = x
			if start>=0 and (rows[y][x]!="1" or x==rows[y].length()-1):
				var end := x+1 if rows[y][x]=="1" else x
				canvas.draw_rect(Rect2(at+Vector2(start,y)*pixel,Vector2(end-start,1)*pixel),color)
				start = -1
