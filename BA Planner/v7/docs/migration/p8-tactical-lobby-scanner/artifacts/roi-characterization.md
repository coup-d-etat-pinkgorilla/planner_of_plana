# P8 tactical lobby ROI characterization

기준 원본은 2560×1440 RGBA PNG다. 전체 화면은 fixture로 보존하되 상대 이름과 원본 ROI는
로컬 recognition/test artifact로만 취급한다.

세 행의 화면 기준 y 구간은 약 347~649, 663~968, 981~1292다. 각 행은 왼쪽부터 상대
프로필, 순위, 공개 스트라이커 1번, 가려진 스트라이커 3칸, 공개 스페셜 2명, 맵 정보,
하단 닉네임 순서다.

ROI는 pixel 좌표를 2560×1440 기준 ratio로 저장하고 같은 16:9 배율에 투영한다. 최초
production support는 2560×1440이며 파생 fixture로 1920×1080과 1280×720 projection을
검증한다.

