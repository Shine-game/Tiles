class_name BotanicalBrush
extends RefCounted

# A tintable watercolor leaf, generated once. Root is at x=0, tip at x=1;
# its baked veins point toward the tip, so rotating it preserves directionality.
static var cached_leaf: Texture2D

static func leaf() -> Texture2D:
	if cached_leaf != null:
		return cached_leaf
	var image := Image.create(160, 80, false, Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(160):
			var u: float = (x + 0.5) / 160.0
			var v: float = (y + 0.5) / 80.0 - 0.5
			var bend: float = sin(u * PI) * 0.035
			var half_width: float = pow(sin(u * PI), 0.85) * 0.43 * (0.87 + 0.13 * u)
			var distance: float = absf(v - bend) / maxf(0.001, half_width)
			if distance >= 1:
				continue
			var grain: float = fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1)
			var wash: float = 0.68 + sin(u * 19 + v * 11) * 0.09 + grain * 0.18
			var boundary: float = 1 - smoothstep(0.88, 1, distance)
			var vein: float = 1 - smoothstep(0.005, 0.018, absf(v - bend))
			for anchor: float in [0.2, 0.38, 0.56, 0.72]:
				if u > anchor and u < anchor + 0.22:
					var rib: float = (u - anchor) * 1.45
					vein = maxf(vein, (1 - smoothstep(0.002, 0.012, absf(absf(v - bend) - rib))) * 0.55)
			var pigment: float = 0.88 + grain * 0.10 - vein * 0.22 - pow(distance, 9) * 0.12
			var alpha: float = boundary * wash * (0.64 + vein * 0.18)
			image.set_pixel(x, y, Color(pigment, pigment, pigment, alpha))
	cached_leaf = ImageTexture.create_from_image(image)
	return cached_leaf
