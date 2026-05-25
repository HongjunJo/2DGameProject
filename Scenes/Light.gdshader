shader_type canvas_item;

uniform vec2 puzzle_pos;      // 퍼즐의 좌상단 스크린 좌표 (픽셀)
uniform vec2 puzzle_size;     // 퍼즐의 가로세로 크기 (픽셀)
uniform vec2 screen_size;     // 현재 화면 해상도 (픽셀)
uniform float padding = 15.0;  // 퍼즐 주변에 남길 아주 약간의 여백 크기
uniform float softness = 20.0; // 스탠드 조명 경계면의 부드러운 페이드 값
uniform vec4 dark_color : source_color = vec4(0.04, 0.04, 0.06, 0.85); // 바깥쪽 어둠의 색상과 투명도

void fragment() {
    // 현재 화면의 픽셀 좌표 계산
    vec2 pixel_pos = UV * screen_size;
    
    // 여백(padding)을 반영한 하이라이트 사각형 영역 정의
    vec2 t_min = puzzle_pos - vec2(padding);
    vec2 t_max = puzzle_pos + puzzle_size + vec2(padding);
    
    // 현재 픽셀이 조명 사각형 영역 바깥으로 얼마나 벗어났는지 연산 (SDF 공식)
    vec2 d = max(t_min - pixel_pos, pixel_pos - t_max);
    float edge_dist = max(d.x, d.y);
    
    // 사각형 경계면을 부드럽게 깎아주는 페이드 계수
    float alpha_factor = smoothstep(0.0, softness, edge_dist);
    
    // 안쪽은 완벽히 투명하게 불이 들어오고, 바깥쪽은 묵직한 어둠으로 덮음
    COLOR = vec4(dark_color.rgb, dark_color.a * alpha_factor);
}