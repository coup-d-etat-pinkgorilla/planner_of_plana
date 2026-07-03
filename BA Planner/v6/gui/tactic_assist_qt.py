from __future__ import annotations

from pathlib import Path

import core.student_meta as student_meta
from core.config import TEMPLATE_DIR
from PySide6.QtCore import QSize, Qt, QTimer
from PySide6.QtGui import QIcon, QKeyEvent, QPixmap
from PySide6.QtWidgets import (
    QCheckBox,
    QFrame,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QPushButton,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from core.raid_guide import RaidGuide
from core.tactic_assist import (
    CARD_MODEL_LEGACY_RANDOM,
    AssistAction,
    AssistSnapshot,
    TacticAssistSession,
    TemplateBattleStateReader,
    UNKNOWN_CARD_ID,
    format_time_ms,
    is_unknown_card,
)


class TacticAssistWindow(QWidget):
    def __init__(self, guide: RaidGuide, *, template_root: Path | None = None, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self._session = TacticAssistSession(guide, TemplateBattleStateReader(template_root))
        self._timer = QTimer(self)
        self._timer.setInterval(350)
        self._timer.timeout.connect(self._tick)

        self.setWindowTitle("Tactic Assist")
        self.setWindowFlags(Qt.Tool | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_StyledBackground, True)
        self.setMinimumWidth(360)
        self.setStyleSheet(
            """
            TacticAssistWindow {
                background: rgba(9, 18, 31, 230);
                color: #f4f8ff;
                border: 1px solid rgba(132, 186, 255, 150);
            }
            QLabel#title {
                font-size: 16px;
                font-weight: 900;
                color: #f4f8ff;
            }
            QLabel#metric {
                color: #a7c7f6;
                font-weight: 800;
            }
            QLabel#current {
                color: #ffffff;
                font-size: 20px;
                font-weight: 900;
            }
            QLabel#subtle {
                color: #9fb2ce;
            }
            QFrame#currentCard {
                background: rgba(38, 67, 105, 210);
                border: 1px solid rgba(145, 202, 255, 170);
                border-radius: 6px;
            }
            QPushButton {
                background: #2f80ed;
                border: 0;
                border-radius: 5px;
                padding: 7px 10px;
                color: white;
                font-weight: 800;
            }
            QPushButton#secondary {
                background: rgba(83, 98, 124, 210);
            }
            QToolButton#handSlot {
                background: rgba(14, 25, 42, 205);
                border: 1px solid rgba(132, 186, 255, 95);
                border-radius: 6px;
                color: #eaf3ff;
                font-weight: 800;
                padding: 5px;
            }
            QToolButton#handSlot:hover {
                border-color: rgba(170, 218, 255, 210);
                background: rgba(41, 78, 123, 215);
            }
            QToolButton#handSlot:disabled {
                color: rgba(234, 243, 255, 90);
                background: rgba(14, 25, 42, 105);
                border-color: rgba(132, 186, 255, 45);
            }
            QListWidget {
                background: rgba(14, 25, 42, 180);
                border: 1px solid rgba(132, 186, 255, 75);
                border-radius: 5px;
                color: #eaf3ff;
            }
            """
        )

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 12, 14, 14)
        root.setSpacing(10)

        self._title = QLabel("")
        self._title.setObjectName("title")
        root.addWidget(self._title)

        metrics = QHBoxLayout()
        self._progress = QLabel("")
        self._progress.setObjectName("metric")
        self._cost = QLabel("")
        self._cost.setObjectName("metric")
        self._time = QLabel("")
        self._time.setObjectName("metric")
        metrics.addWidget(self._progress)
        metrics.addWidget(self._cost)
        metrics.addWidget(self._time)
        metrics.addStretch(1)
        root.addLayout(metrics)

        self._legacy_mode = QCheckBox("구버전 랜덤 큐")
        self._legacy_mode.setObjectName("subtle")
        self._legacy_mode.toggled.connect(self._set_legacy_mode)
        root.addWidget(self._legacy_mode)

        current_card = QFrame()
        current_card.setObjectName("currentCard")
        current_layout = QVBoxLayout(current_card)
        current_layout.setContentsMargins(12, 10, 12, 12)
        current_layout.setSpacing(6)
        self._cue = QLabel("")
        self._cue.setObjectName("subtle")
        self._current = QLabel("")
        self._current.setObjectName("current")
        self._current.setWordWrap(True)
        self._target = QLabel("")
        self._target.setObjectName("subtle")
        self._block = QLabel("")
        self._block.setObjectName("subtle")
        self._use_button = QPushButton("스킬 사용 확인")
        self._use_button.clicked.connect(lambda: self._advance("button"))
        current_layout.addWidget(self._cue)
        current_layout.addWidget(self._current)
        current_layout.addWidget(self._target)
        current_layout.addWidget(self._block)
        current_layout.addWidget(self._use_button)
        root.addWidget(current_card)

        root.addWidget(QLabel("손패 시뮬레이션 (1~5)"))
        hand_row = QHBoxLayout()
        hand_row.setSpacing(6)
        self._hand_buttons: list[QToolButton] = []
        for index in range(5):
            button = QToolButton()
            button.setObjectName("handSlot")
            button.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
            button.setIconSize(QSize(48, 48))
            button.setFixedSize(QSize(66, 84))
            button.clicked.connect(lambda _checked=False, slot=index: self._use_hand_slot(slot))
            self._hand_buttons.append(button)
            hand_row.addWidget(button)
        hand_row.addStretch(1)
        root.addLayout(hand_row)

        self._upcoming = QListWidget()
        self._upcoming.setMinimumHeight(124)
        root.addWidget(QLabel("다음 택틱"))
        root.addWidget(self._upcoming)

        self._used = QLabel("")
        self._used.setWordWrap(True)
        self._used.setObjectName("subtle")
        self._queue = QLabel("")
        self._queue.setWordWrap(True)
        self._queue.setObjectName("subtle")
        root.addWidget(self._used)
        root.addWidget(self._queue)

        buttons = QHBoxLayout()
        skip = QPushButton("스킵")
        skip.setObjectName("secondary")
        skip.clicked.connect(self._skip)
        reset = QPushButton("초기화")
        reset.setObjectName("secondary")
        reset.clicked.connect(lambda: self._reset("manual"))
        buttons.addWidget(skip)
        buttons.addWidget(reset)
        root.addLayout(buttons)

        self._status = QLabel("")
        self._status.setObjectName("subtle")
        self._status.setWordWrap(True)
        root.addWidget(self._status)

        self._render(self._session.snapshot())

    def show(self) -> None:
        self._timer.start()
        self._position_near_game()
        super().show()
        self.raise_()

    def closeEvent(self, event) -> None:
        self._timer.stop()
        super().closeEvent(event)

    def keyPressEvent(self, event: QKeyEvent) -> None:
        if self._session.handle_key(
            int(event.key()),
            escape_key=int(Qt.Key_Escape),
            r_key=int(Qt.Key_R),
            space_key=int(Qt.Key_Space),
        ):
            self._render(self._session.snapshot())
            event.accept()
            return
        number_keys = {
            int(Qt.Key_1): 0,
            int(Qt.Key_2): 1,
            int(Qt.Key_3): 2,
            int(Qt.Key_4): 3,
            int(Qt.Key_5): 4,
        }
        slot = number_keys.get(int(event.key()))
        if slot is not None:
            self._use_hand_slot(slot)
            event.accept()
            return
        super().keyPressEvent(event)

    def _tick(self) -> None:
        self._render(self._session.poll())
        self._position_near_game()

    def _advance(self, source: str) -> None:
        self._session.advance_current(source)
        self._render(self._session.snapshot())

    def _skip(self) -> None:
        self._session.skip_current()
        self._render(self._session.snapshot())

    def _reset(self, reason: str) -> None:
        self._session.reset(reason)
        self._render(self._session.snapshot())

    def _set_legacy_mode(self, checked: bool) -> None:
        self._session.set_card_model(CARD_MODEL_LEGACY_RANDOM if checked else "")
        self._render(self._session.snapshot())

    def _use_hand_slot(self, slot_index: int) -> None:
        self._session.use_hand_slot(slot_index)
        self._render(self._session.snapshot())

    def _render(self, snapshot: AssistSnapshot) -> None:
        self._title.setText(snapshot.title)
        self._progress.setText(f"Step {snapshot.progress}")
        self._cost.setText("Cost --" if snapshot.cost is None else f"Cost {snapshot.cost:g}")
        self._time.setText(f"Time {format_time_ms(snapshot.remaining_ms)}")

        current = snapshot.current
        if current is None:
            self._cue.setText("Complete")
            self._current.setText("택틱 완료")
            self._target.setText("")
            self._block.setText("")
            self._use_button.setEnabled(False)
        else:
            self._cue.setText(self._cue_text(current))
            self._current.setText(self._action_label(current))
            target = f"Target: {current.target_label}" if current.target_label else ""
            self._target.setText(target)
            self._block.setText("" if current.ready else current.blocked_reason)
            self._use_button.setEnabled(True)

        self._upcoming.clear()
        for action in snapshot.upcoming:
            self._upcoming.addItem(f"{self._cue_text(action)}  {self._action_label(action)}")
        if not snapshot.upcoming:
            self._upcoming.addItem("남은 택틱 없음")

        self._render_hand(snapshot)
        self._used.setText("Used: " + (", ".join(snapshot.used) if snapshot.used else "-"))
        self._queue.setText("Queue: " + (", ".join(snapshot.queue) if snapshot.queue else "-"))
        retry = " | retry sequence armed" if snapshot.retry_armed else ""
        self._status.setText((snapshot.status or "Ready") + retry)

    def _render_hand(self, snapshot: AssistSnapshot) -> None:
        for index, button in enumerate(self._hand_buttons):
            if index < len(snapshot.hand_ids):
                student_id = snapshot.hand_ids[index]
                label = snapshot.hand[index] if index < len(snapshot.hand) else student_id
                button.setEnabled(True)
                display_label = "?" if is_unknown_card(student_id) else label
                button.setText(f"{index + 1}\n{display_label}")
                button.setIcon(self._student_icon(student_id))
                button.setToolTip(f"{index + 1}: {label}")
            else:
                button.setEnabled(False)
                button.setText(f"{index + 1}\n-")
                button.setIcon(QIcon())
                button.setToolTip("")

    def _student_form_index(self, student_id: str) -> int:
        for slot in self._guide.deck:
            if slot.student_id == student_id:
                return student_meta.normalize_form_index(student_id, getattr(slot, "form_index", 1))
        return 1

    def _student_icon(self, student_id: str) -> QIcon:
        if is_unknown_card(student_id):
            return QIcon()
        form_index = self._student_form_index(student_id)
        template_name = student_meta.template_path_for_form(student_id, form_index)
        template_stem = Path(template_name).stem
        candidates = [
            TEMPLATE_DIR / "students_portraits" / template_name,
            TEMPLATE_DIR / "students_portraits" / f"{template_stem}.png",
            TEMPLATE_DIR / "students_portraits" / f"{student_id}.png",
            TEMPLATE_DIR / "students" / template_name,
            TEMPLATE_DIR / "students" / f"{student_id}.png",
        ]
        for path in candidates:
            if path.exists():
                pixmap = QPixmap(str(path))
                if not pixmap.isNull():
                    scaled = pixmap.scaled(48, 48, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                    return QIcon(scaled)
        return QIcon()

    def _position_near_game(self) -> None:
        from core.capture import get_window_rect

        rect = get_window_rect()
        if rect is None:
            return
        left, top, width, height = rect
        margin = 16
        self.adjustSize()
        target_w = self.width()
        target_h = self.height()
        x = left + width - target_w - margin
        y = top + max(margin, int(height * 0.10))
        self.move(max(0, x), max(0, y))

    @staticmethod
    def _cue_text(action: AssistAction) -> str:
        step = action.step
        if step.cost_value is not None:
            return f"{step.cost_value:g} cost"
        if step.time_ms is not None:
            return format_time_ms(step.time_ms)
        return step.cue_text or "trigger"

    @staticmethod
    def _action_label(action: AssistAction) -> str:
        step = action.step
        actor = action.actor_label or step.actor_student_id or step.note or "Marker"
        action_type = (step.action_type or "EX").strip()
        return actor if action_type in {"", "EX", "marker"} else f"{actor} {action_type}"
