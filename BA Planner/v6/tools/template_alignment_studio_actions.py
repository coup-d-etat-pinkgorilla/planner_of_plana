"""Interaction methods for Template Alignment Studio."""

from pathlib import Path

from PIL import Image
from PySide6.QtCore import QPointF, Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QColorDialog, QFileDialog, QGraphicsItem, QGraphicsRectItem, QInputDialog,
    QListWidgetItem, QMessageBox,
)

from tools.template_alignment_studio_model import (
    LayerSpec, RoiSpec, export_project, load_project, render_layer, save_project,
)
from tools.template_alignment_tool import IMAGE_FILTER, LayerItem, pil_to_pixmap


class RoiItem(QGraphicsRectItem):
    def __init__(self, index, moved, selected):
        super().__init__()
        self.index, self.moved_callback, self.selected_callback = index, moved, selected
        self.setFlags(
            QGraphicsItem.ItemIsMovable | QGraphicsItem.ItemIsSelectable
            | QGraphicsItem.ItemSendsGeometryChanges
        )

    def itemChange(self, change, value):
        if change == QGraphicsItem.ItemPositionChange:
            return QPointF(round(value.x()), round(value.y()))
        if change == QGraphicsItem.ItemPositionHasChanged:
            self.moved_callback(self.index, round(self.pos().x()), round(self.pos().y()))
        if change == QGraphicsItem.ItemSelectedHasChanged and bool(value):
            self.selected_callback(self.index)
        return super().itemChange(change, value)


class StudioActionsMixin:
    def choose_reference(self):
        path, _ = QFileDialog.getOpenFileName(self, "Reference screenshot", "", IMAGE_FILTER)
        if path:
            self.set_reference(Path(path))

    def set_reference(self, path):
        image = Image.open(path).convert("RGBA")
        self.project.reference_path = str(Path(path).resolve())
        self.reference_item.setPixmap(pil_to_pixmap(image))
        self.scene.setSceneRect(0, 0, image.width, image.height)
        if len(self.project.rois) == 1 and self.project.rois[0] == RoiSpec():
            self.project.rois[0] = RoiSpec("main", 0, 0, image.width, image.height)
            self.rebuild_rois()
        self.fit()

    def choose_images(self):
        paths, _ = QFileDialog.getOpenFileNames(self, "Add image layers", "", IMAGE_FILTER)
        for value in paths:
            path, image = Path(value), Image.open(value)
            self.project.layers.append(
                LayerSpec(path.stem, "image", str(path.resolve()), width=image.width,
                          height=image.height)
            )
        self.rebuild_layers(len(self.project.layers) - 1)

    def add_text(self):
        text, ok = QInputDialog.getText(self, "Add text layer", "Text", text="Lv.70")
        if not ok:
            return
        self.project.layers.append(
            LayerSpec(text or "Text", "text", width=180, height=60,
                      opacity=100, text=text or "Lv.70")
        )
        self.rebuild_layers(len(self.project.layers) - 1)

    def rebuild_layers(self, selected=0):
        for item in self.layer_items:
            self.scene.removeItem(item)
        self.layer_items.clear(); self.layer_list.clear()
        for index, layer in enumerate(self.project.layers):
            item = LayerItem(index, self.layer_moved)
            self.scene.addItem(item); self.layer_items.append(item)
            self.layer_list.addItem(QListWidgetItem(f"[{layer.kind}] {layer.name}"))
            self.refresh_layer(index)
        if self.project.layers:
            self.layer_list.setCurrentRow(max(0, min(selected, len(self.project.layers)-1)))

    def refresh_layer(self, index):
        layer, item = self.project.layers[index], self.layer_items[index]
        item.setPixmap(pil_to_pixmap(render_layer(layer)))
        item.setPos(layer.x, layer.y); item.setOpacity(1.0)
        item.setVisible(layer.visible); item.setZValue(index)

    def select_layer(self, index):
        if not 0 <= index < len(self.project.layers): return
        self._updating = True
        layer = self.project.layers[index]
        for widget, value in ((self.lx,layer.x),(self.ly,layer.y),(self.lw,layer.width),
                              (self.lh,layer.height),(self.opacity,layer.opacity),
                              (self.font_size,layer.font_size),(self.stroke_width,layer.stroke_width)):
            widget.setValue(value)
        self.visible.setChecked(layer.visible); self.text_bold.setChecked(layer.text_bold)
        self.text_value.setText(layer.text)
        self.font_path.setText(layer.font_path); self.shear.setValue(layer.shear)
        self.fill_value.setText(layer.fill); self.stroke_value.setText(layer.stroke_fill)
        self.text_group.setEnabled(layer.kind == "text")
        self.layer_items[index].setSelected(True)
        self._updating = False

    def layer_changed(self, *_):
        index = self.layer_list.currentRow()
        if self._updating or not 0 <= index < len(self.project.layers): return
        layer = self.project.layers[index]
        layer.x,layer.y,layer.width,layer.height=self.lx.value(),self.ly.value(),self.lw.value(),self.lh.value()
        layer.opacity,layer.visible=self.opacity.value(),self.visible.isChecked()
        if layer.kind == "text":
            layer.text=self.text_value.text(); layer.font_path=self.font_path.text()
            layer.font_size=self.font_size.value(); layer.fill=self.fill_value.text()
            layer.stroke_width=self.stroke_width.value(); layer.stroke_fill=self.stroke_value.text()
            layer.text_bold=self.text_bold.isChecked(); layer.shear=self.shear.value()
        self.refresh_layer(index)

    def layer_moved(self,index,x,y):
        if self._updating or not 0 <= index < len(self.project.layers): return
        self.project.layers[index].x,self.project.layers[index].y=x,y
        if self.layer_list.currentRow()==index:
            self._updating=True; self.lx.setValue(x); self.ly.setValue(y); self._updating=False

    def remove_layer(self):
        index=self.layer_list.currentRow()
        if 0<=index<len(self.project.layers):
            del self.project.layers[index]; self.rebuild_layers(index)

    def reorder_layer(self,delta):
        index=self.layer_list.currentRow(); target=index+delta
        if 0<=index<len(self.project.layers) and 0<=target<len(self.project.layers):
            self.project.layers[index],self.project.layers[target]=self.project.layers[target],self.project.layers[index]
            self.rebuild_layers(target)

    def choose_font(self):
        path,_=QFileDialog.getOpenFileName(self,"Font file",self.font_path.text(),"Fonts (*.ttf *.otf *.ttc)")
        if path: self.font_path.setText(path); self.layer_changed()

    def choose_color(self,target):
        edit=self.fill_value if target=="fill" else self.stroke_value
        color=QColorDialog.getColor(QColor(edit.text()),self)
        if color.isValid(): edit.setText(color.name(QColor.HexRgb)); self.layer_changed()

    def add_roi(self):
        name,ok=QInputDialog.getText(self,"New ROI","Name",text="favorite_t1_marker")
        if ok:
            self.project.rois.append(RoiSpec(name or f"roi_{len(self.project.rois)+1}"))
            self.rebuild_rois(len(self.project.rois)-1)

    def remove_roi(self):
        index=self.roi_list.currentRow()
        if 0<=index<len(self.project.rois) and len(self.project.rois)>1:
            del self.project.rois[index]; self.rebuild_rois(index)

    def rebuild_rois(self,selected=0):
        for item in self.roi_items: self.scene.removeItem(item)
        self.roi_items.clear(); self.roi_list.clear()
        colors=(QColor(255,55,80),QColor(30,210,255),QColor(255,190,40),QColor(150,100,255))
        for index,roi in enumerate(self.project.rois):
            item=RoiItem(index,self.roi_moved,self.roi_item_selected)
            color=colors[index%len(colors)]; item.setPen(self.roi_pen(color)); item.setBrush(QColor(color.red(),color.green(),color.blue(),18))
            item.setRect(0,0,roi.width,roi.height); item.setPos(roi.x,roi.y); item.setZValue(1000+index)
            item.setVisible(roi.enabled); self.scene.addItem(item); self.roi_items.append(item)
            self.roi_list.addItem(QListWidgetItem(roi.name))
        if self.project.rois: self.roi_list.setCurrentRow(max(0,min(selected,len(self.project.rois)-1)))

    def roi_item_selected(self,index): self.roi_list.setCurrentRow(index)

    def select_roi(self,index):
        if not 0<=index<len(self.project.rois): return
        self._updating=True; roi=self.project.rois[index]
        self.roi_name.setText(roi.name); self.roi_enabled.setChecked(roi.enabled)
        for widget,value in ((self.rx,roi.x),(self.ry,roi.y),(self.rw,roi.width),(self.rh,roi.height)): widget.setValue(value)
        self.roi_items[index].setSelected(True); self._updating=False

    def roi_changed(self,*_):
        index=self.roi_list.currentRow()
        if self._updating or not 0<=index<len(self.project.rois): return
        roi=self.project.rois[index]; roi.name=self.roi_name.text() or roi.name; roi.enabled=self.roi_enabled.isChecked()
        roi.x,roi.y,roi.width,roi.height=self.rx.value(),self.ry.value(),self.rw.value(),self.rh.value()
        item=self.roi_items[index]; item.setRect(0,0,roi.width,roi.height); item.setPos(roi.x,roi.y); item.setVisible(roi.enabled)
        self.roi_list.item(index).setText(roi.name)

    def roi_moved(self,index,x,y):
        if self._updating:return
        roi=self.project.rois[index]; roi.x,roi.y=x,y
        if self.roi_list.currentRow()==index:
            self._updating=True; self.rx.setValue(x); self.ry.setValue(y); self._updating=False

    def nudge(self,dx,dy):
        selected=[i for i,item in enumerate(self.roi_items) if item.isSelected()]
        if selected:
            self.rx.setValue(self.rx.value()+dx); self.ry.setValue(self.ry.value()+dy)
        elif 0<=self.layer_list.currentRow()<len(self.project.layers):
            self.lx.setValue(self.lx.value()+dx); self.ly.setValue(self.ly.value()+dy)

    def fit(self):
        if not self.scene.sceneRect().isEmpty(): self.view.fitInView(self.scene.sceneRect(),Qt.KeepAspectRatio)
