class_name AssetPaths
extends RefCounted

## 그림 파일 경로·존재 확인·읽기 도우미. 자동 로드(SpriteCacheManager)에 기대지 않아 어느 스크립트에서나 쓸 수 있다.
## PORT-TRACE [내보낸 게임 예전 그림]: 내보낸 .pck에는 원본 PNG가 없고 가져온(import) 그림만 들어 있다.
## 편집기에선 프로젝트 폴더의 원본 PNG를 바로 읽고(가져오기 전 새 그림 포함), 내보낸 게임에선 패키지 안 그림을 읽는다.

static var _can_write_cache: int = -1

## 편집기에서 실행할 때만 true. 내보낸 게임의 res://는 읽기 전용 패키지(.pck)라 그림을 굽거나 저장하지 않는다.
## PORT-TRACE [가짜 내보내기 템플릿]: 내보내기 템플릿 자리에 편집기 exe가 들어가 있으면 내보낸 게임도 "editor" 기능을 가진다 —
## 원본 project.godot은 프로젝트 폴더에만 있고 패키지(.pck)에는 project.binary만 들어가므로 그것까지 확인한다.
static func can_write_assets() -> bool:
	if _can_write_cache < 0:
		_can_write_cache = 1 if (OS.has_feature("editor") and FileAccess.file_exists("res://project.godot")) else 0
	return _can_write_cache == 1

## 파일을 찾을 경로: 편집기에선 프로젝트 폴더의 실제 경로, 내보낸 게임에선 패키지 안 res:// 경로 그대로.
## (내보낸 게임에서 globalize_path는 exe 옆 폴더를 가리켜 패키지 안 새 그림을 못 찾는다)
static func disk_path(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path) if can_write_assets() else res_path

## 그림 파일이 있는가: 편집기에선 폴더의 원본 PNG, 내보낸 게임에선 패키지 안 가져온 그림.
static func asset_exists(res_path: String) -> bool:
	if can_write_assets() and FileAccess.file_exists(disk_path(res_path)):
		return true
	return ResourceLoader.exists(res_path)

## 그림 읽기: 편집기에선 원본 PNG를 바로 읽고, 내보낸 게임에선 패키지 안 가져온 그림을 읽는다. 없으면 null.
static func load_asset_texture(res_path: String) -> Texture2D:
	if can_write_assets():
		var gp: String = disk_path(res_path)
		if FileAccess.file_exists(gp):
			var img := Image.load_from_file(gp)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null
