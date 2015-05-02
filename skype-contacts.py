__kupfer_name__ = _("Skype contacts")
__kupfer_sources__ = ("SkypeContactsSource", )
__kupfer_actions__ = ("ChatWith", )
__description__ = _("A plugin to focus Skype and open a chat in it")
__version__ = "1.0"
__author__ = "Dzmitry Paulenka"

import gio
import os
from kupfer import plugin_support
from kupfer import pretty
from kupfer import utils
from kupfer.objects import Leaf, Source, Action


class SkypeContactsSource(Source):
  contacts_file_path = "~/.local/share/kupfer/plugins/skype-contacts.list"

  def __init__(self):
    Source.__init__(self, _("Skype contacts"))

  def initialize(self):
    gfile = gio.File(os.path.expanduser(self.contacts_file_path))
    self.monitor = gfile.monitor_file(gio.FILE_MONITOR_NONE, None)
    if self.monitor:
      self.monitor.connect("changed", self._changed)

  def _changed(self, monitor, file1, file2, evt_type):
    """Change callback; something changed"""
    if evt_type in (gio.FILE_MONITOR_EVENT_CREATED,
                    gio.FILE_MONITOR_EVENT_DELETED,
                    gio.FILE_MONITOR_EVENT_CHANGED):
      self.mark_for_update()

  def get_items(self):
    contacts_file = os.path.expanduser(self.contacts_file_path)
    if not os.path.exists(contacts_file):
      self.output_debug("Contacts file not found at: ", contacts_file)
      return

    try:
      for line in open(contacts_file, "r"):
        self.output_debug("Line from contacts: ", line)
        skypeIds, displayName = line.strip().split("|")
        yield Contact(skypeIds, displayName)
    except EnvironmentError:
      self.output_exc()
      return

  def provides(self):
    yield Contact


class Contact(Leaf):
  def __init__(self, skypeId, name):
    Leaf.__init__(self, skypeId, name)

  def get_actions(self):
    yield ChatWith()

  def repr_key(self):
    return self.object

    # def get_icon(self):
    # TODO:

class ChatWith(Action):
  def __init__(self):
    Action.__init__(self, _("Chat with"))

  def activate(self, leaf):
    skypeId = leaf.object
    utils.spawn_async(["sh", "-c",
                       'skype "skype:' + skypeId + '"' +
                       ' && xdotool search --sync --onlyvisible --name "' + leaf.name + '"'
                       '  | xargs -n 1 -I {} xdotool windowactivate --sync {}'])

  def get_description(self):
    return _("Open existing skype chat")

    # def get_gicon(self):
    # TODO:
