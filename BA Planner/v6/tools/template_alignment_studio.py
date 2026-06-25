"""Layered text/template composer and named pixel-ROI editor."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtGui import QAction, QColor, QPen
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QDoubleSpinBox, QFormLayout, QGraphicsPixmapItem,
    QGraphicsScene, QGroupBox, QHBoxLayout, QLabel, QLineEdit, QListWidget,
    QMainWindow, QPushButton, QSlider, QSpinBox, QSplitter, QTabWidget,
    QToolBar, QVBoxLayout, QWidget,
)

from tools.template_alignment_studio_actions import StudioActionsMixin
from tools.template_alignment_studio_model import StudioProject
from tools.template_alignment_studio_project import StudioProjectMixin
from tools.template_alignment_tool import LayerItem, PixelView


class StudioWindow(StudioActionsMixin, StudioProjectMixin, QMainWindow):
    def __init__(self, project_path=None):
        super().__init__(); self.setWindowTitle("Template Alignment Studio"); self.resize(1540,940)
        self.project, self.project_path = StudioProject(), project_path
        self.scene=QGraphicsScene(self); self.view=PixelView(self.scene)
        self.view.cursor_moved.connect(lambda x,y:self.statusBar().showMessage(f"pixel: {x}, {y}"))
        self.view.nudge_requested.connect(self.nudge)
        self.reference_item=QGraphicsPixmapItem(); self.reference_item.setZValue(-1000); self.scene.addItem(self.reference_item)
        self.layer_items:list[LayerItem]=[]; self.roi_items=[]; self._updating=False
        split=QSplitter(); split.addWidget(self.view); split.addWidget(self.side_panel()); split.setSizes([1120,420])
        self.setCentralWidget(split); self.toolbar(); self.rebuild_rois()
        if project_path: self.open_project(project_path)

    @staticmethod
    def spin(minimum=-10000,maximum=10000):
        value=QSpinBox(); value.setRange(minimum,maximum); return value

    @staticmethod
    def roi_pen(color): return QPen(color,1)

    def toolbar(self):
        bar=QToolBar("Studio"); self.addToolBar(bar)
        for text,callback in (
            ("Reference",self.choose_reference),("Add image",self.choose_images),("Add text",self.add_text),
            ("Open",self.choose_project),("Save",self.choose_save),("Export ROIs",self.choose_export),
            ("Fit",self.fit),("100%",self.view.resetTransform),
        ):
            action=QAction(text,self); action.triggered.connect(callback); bar.addAction(action)

    def side_panel(self):
        tabs=QTabWidget(); tabs.addTab(self.layer_panel(),"Layers & text"); tabs.addTab(self.roi_panel(),"Named ROIs")
        return tabs

    def layer_panel(self):
        panel=QWidget(); root=QVBoxLayout(panel); root.addWidget(QLabel("Layers (bottom to top)"))
        self.layer_list=QListWidget(); self.layer_list.currentRowChanged.connect(self.select_layer); root.addWidget(self.layer_list,1)
        row=QHBoxLayout()
        for text,callback in (("+ Image",self.choose_images),("+ Text",self.add_text),("Remove",self.remove_layer),
                              ("Up",lambda:self.reorder_layer(1)),("Down",lambda:self.reorder_layer(-1))):
            button=QPushButton(text); button.clicked.connect(callback); row.addWidget(button)
        root.addLayout(row)
        self.visible=QCheckBox("Visible"); self.opacity=QSlider(Qt.Horizontal); self.opacity.setRange(0,100)
        self.lx,self.ly=self.spin(),self.spin(); self.lw,self.lh=self.spin(1,20000),self.spin(1,20000)
        form=QFormLayout()
        for label,widget in (("",self.visible),("Opacity",self.opacity),("X",self.lx),("Y",self.ly),
                             ("Width",self.lw),("Height",self.lh)): form.addRow(label,widget)
        root.addLayout(form)
        self.text_group=QGroupBox("Text rendering"); text_form=QFormLayout(self.text_group)
        self.text_value=QLineEdit("Lv.70"); self.font_path=QLineEdit("C:/Windows/Fonts/arialbd.ttf")
        font_row=QWidget(); font_layout=QHBoxLayout(font_row); font_layout.setContentsMargins(0,0,0,0)
        font_layout.addWidget(self.font_path); browse=QPushButton("..."); browse.clicked.connect(self.choose_font); font_layout.addWidget(browse)
        self.font_size=self.spin(1,500); self.text_bold=QCheckBox("Bold"); self.fill_value=QLineEdit("#FFFFFFFF"); self.stroke_width=self.spin(0,30)
        self.stroke_value=QLineEdit("#FF000000"); self.shear=QDoubleSpinBox(); self.shear.setRange(-2,2); self.shear.setSingleStep(.05)
        fill_button=QPushButton("Pick"); fill_button.clicked.connect(lambda:self.choose_color("fill"))
        stroke_button=QPushButton("Pick"); stroke_button.clicked.connect(lambda:self.choose_color("stroke"))
        fill_row=QWidget(); fl=QHBoxLayout(fill_row); fl.setContentsMargins(0,0,0,0); fl.addWidget(self.fill_value); fl.addWidget(fill_button)
        stroke_row=QWidget(); sl=QHBoxLayout(stroke_row); sl.setContentsMargins(0,0,0,0); sl.addWidget(self.stroke_value); sl.addWidget(stroke_button)
        for label,widget in (("Text",self.text_value),("Font file",font_row),("Font size",self.font_size),
                             ("",self.text_bold),("Fill",fill_row),("Stroke px",self.stroke_width),
                             ("Stroke color",stroke_row),("Shear",self.shear)):
            text_form.addRow(label,widget)
        root.addWidget(self.text_group)
        self.visible.toggled.connect(self.layer_changed); self.text_bold.toggled.connect(self.layer_changed)
        for widget in (self.opacity,self.lx,self.ly,self.lw,self.lh,self.font_size,self.stroke_width): widget.valueChanged.connect(self.layer_changed)
        self.shear.valueChanged.connect(self.layer_changed)
        for widget in (self.text_value,self.font_path,self.fill_value,self.stroke_value): widget.editingFinished.connect(self.layer_changed)
        blink=QPushButton("Hold to hide layers"); blink.pressed.connect(lambda:self.show_layers(False)); blink.released.connect(lambda:self.show_layers(True)); root.addWidget(blink)
        self.text_group.setEnabled(False); return panel

    def roi_panel(self):
        panel=QWidget(); root=QVBoxLayout(panel)
        root.addWidget(QLabel("Named matcher ROIs. Drag rectangles on the canvas; resize here."))
        self.roi_list=QListWidget(); self.roi_list.currentRowChanged.connect(self.select_roi); root.addWidget(self.roi_list,1)
        row=QHBoxLayout(); add=QPushButton("New ROI"); add.clicked.connect(self.add_roi); remove=QPushButton("Remove"); remove.clicked.connect(self.remove_roi)
        row.addWidget(add); row.addWidget(remove); root.addLayout(row)
        self.roi_name=QLineEdit("main"); self.roi_enabled=QCheckBox("Enabled"); self.roi_enabled.setChecked(True)
        self.rx,self.ry=self.spin(),self.spin(); self.rw,self.rh=self.spin(1,20000),self.spin(1,20000)
        form=QFormLayout()
        for label,widget in (("Name",self.roi_name),("",self.roi_enabled),("X",self.rx),("Y",self.ry),
                             ("Width",self.rw),("Height",self.rh)): form.addRow(label,widget)
        root.addLayout(form)
        self.roi_name.editingFinished.connect(self.roi_changed); self.roi_enabled.toggled.connect(self.roi_changed)
        for widget in (self.rx,self.ry,self.rw,self.rh): widget.valueChanged.connect(self.roi_changed)
        root.addWidget(QLabel("Suggested names: main, equipment_icon, favorite_t1_marker, favorite_t2_marker"))
        return panel


def parse_args():
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument("project",nargs="?",type=Path)
    parser.add_argument("--reference",type=Path); parser.add_argument("--layer",type=Path,action="append",default=[])
    return parser.parse_args()


def main():
    args=parse_args(); app=QApplication(sys.argv); window=StudioWindow(args.project)
    if args.reference and not args.project: window.set_reference(args.reference)
    for layer in args.layer:
        image=__import__('PIL.Image',fromlist=['Image']).open(layer)
        window.project.layers.append(__import__('tools.template_alignment_studio_model',fromlist=['LayerSpec']).LayerSpec(layer.stem,"image",str(layer.resolve()),width=image.width,height=image.height))
    if args.layer: window.rebuild_layers()
    window.show(); return app.exec()


if __name__=="__main__": raise SystemExit(main())
