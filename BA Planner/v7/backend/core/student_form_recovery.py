"""Read other-form combat values, then positively verify the original form."""
from threading import Event
from core import student_meta
from core.scanner_session import ScannerError


class StudentFormRecovery:
    def __init__(self, capture, regions):
        self.capture, self.regions = capture, regions
        self.trace = []

    def _switch(self, target, cancel, original_base, form, observe):
        frame, identity = observe(target, cancel)
        base, current = student_meta.split_form_ref(identity.student_ref)
        if base != original_base:
            frame.close()
            raise ScannerError('form_student_changed', 'form navigation cannot act on another student')
        if current == form:
            return frame, identity
        frame.close()
        button = self.regions.get(f'style_form_{form}_button')
        if not isinstance(button, dict):
            raise ScannerError('region_missing', 'requested form button is unavailable')
        if cancel.is_set():
            raise ScannerError('cancelled', 'form switch cancelled')
        self.capture.click({**target, '_scanner_cancel': cancel},
                           (button['x1']+button['x2'])/2, (button['y1']+button['y2'])/2)
        self.trace.append(dict(input='form', form=form))
        for _ in range(2):
            if cancel.wait(.35):
                raise ScannerError('cancelled', 'form transition cancelled')
            frame, identity = observe(target, cancel)
            base, current = student_meta.split_form_ref(identity.student_ref)
            self.trace.append(dict(observed=identity.student_ref))
            if base == original_base and current == form:
                return frame, identity
            frame.close()
            if base != original_base:
                raise ScannerError('form_student_changed', 'another student appeared after form input')
        raise ScannerError('form_unconfirmed', 'form button did not reach requested form')

    def collect(self, target, cancel, original_ref, observe, read_form):
        base, original = student_meta.split_form_ref(original_ref)
        self.trace = []
        target = {**target, '_first_student': False}
        failure = None
        try:
            for form in student_meta.form_indexes(base):
                if form == original:
                    continue
                frame, identity = self._switch(target, cancel, base, form, observe)
                try:
                    read_form(frame, identity)
                    if cancel.is_set():
                        raise ScannerError('cancelled', 'form read cancelled; restore original form')
                finally:
                    frame.close()
        except Exception as exc:
            failure = exc if isinstance(exc, ScannerError) else ScannerError('form_read_failed', str(exc))
        finally:
            cleanup = {**target, '_scanner_cleanup': True, '_scanner_cancel': Event()}
            try:
                frame, _identity = self._switch(cleanup, cleanup['_scanner_cancel'], base, original, observe)
                frame.close()
                self.trace.append(dict(restored=original_ref))
            except Exception as exc:
                raise ScannerError('form_restore_failed', 'original student/form could not be verified') from exc
        if failure is not None:
            if isinstance(failure, ScannerError):
                failure.details['screen_state'] = 'basic'
                failure.details['form_restored'] = True
            raise failure
