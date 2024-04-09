# python 3 headers, required if submitting to Ansible
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r"""
  name: server_volumes
  author: Socle Cloud Team <list.fr-ttis-tech-ast-scl@socgen.com>
  version_added: "0.1"  # for collections, use the collection version, not the Ansible version
  short_description: read file contents
  description:
      - This lookup returns the contents from a file on the Ansible controller's file system.
  options:
    _terms:
      description: uuid of the server
      type: string
      required: True
    region: 
      description: SG Cloud Platform region
      type: string
      default: 'eu-fr-paris'
    return_detail: 
      description: Return volumes detail if true, by default it only returns uids
      type: bool
      default: False
  notes:
    - list volumes attached for a given vm uid
"""

EXAMPLES = """
- name: Print My Paris VM Volumes UIDs
  debug:
    msg: "{{ lookup('cloudplatform.ocs.server_volumes', '1956e8ae-5064-4a2b-ae0c-0a991a3a0dba', wantlist=True) }}"

- name: Print My North VM Volumes
  debug:
    msg: "{{ lookup('cloudplatform.ocs.server_volumes', '1956e8ae-5064-4a2b-ae0c-0a991a3a0dba', region='eu-fr-north', return_detail=True) }}"
"""

RETURN = """
  _list:
    description:
      - list of volumes attached to the server
    type: list
"""

import json
from uuid import UUID
from datetime import timezone
from ansible.errors import AnsibleError, AnsibleParserError
from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
from cloudplatform_sdk import CloudPlatformClient, IAMCredentials

display = Display()

class LookupModule(LookupBase):

    def run(self, terms, variables=None, **kwargs):

      # First of all populate options,
      # this will already take into account env vars and ini config
      self.set_options(var_options=variables, direct=kwargs)

      ret = []
      try:
        server_uid = str(UUID(terms[0], version=4))
      except ValueError:
        raise AnsibleError("Invalid server UID: %s" % terms[0])

      client = CloudPlatformClient(main_region=self.get_option('region'))
      if self.get_option('return_detail'):
        for vol in client.ocs.servers.list_volumes(server=server_uid):
            ret.append({
                'availability_zone': vol.availability_zone,
                'created_at': vol.created_at.astimezone(timezone.utc).strftime("%m/%d/%Y %H:%M:%S (UTC)"),
                'description': vol.description,
                'name': vol.name,
                'size': vol.size,
                'status': vol.status,
                'all_tags': vol.all_tags,
                'updated_at': vol.updated_at.astimezone(timezone.utc).strftime("%m/%d/%Y %H:%M:%S (UTC)"),
                'volume_type': vol.volume_type,
                'attachments': [{'uid': attach.uid, 'attached_at': attach.attached_at.astimezone(timezone.utc).strftime("%m/%d/%Y %H:%M:%S (UTC)"), 'device': attach.device, 'server_uid': attach.server_uid} for attach in vol.attachments]
            })
      else:
        ret = client.ocs.servers.list_volume_uids(server=server_uid)

      return ret
