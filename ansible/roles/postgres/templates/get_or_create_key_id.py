#!/usr/bin/python3
import sys
from kmip.pie import client
from kmip import enums
from kmip.core.factories import attributes

def main():
    key_name = sys.argv[1]
    pykmip_conf_path=sys.argv[2]
    c = client.ProxyKmipClient(config_file=pykmip_conf_path)
    f = attributes.AttributeFactory()
    c.open()
    key_id_list=c.locate(attributes=[f.create_attribute(enums.AttributeType.NAME, key_name)])
   # print(key_id_list)
    if len(key_id_list) == 0:
        #print('Unknowed key_mane so to be created')
        key_id = c.create(enums.CryptographicAlgorithm.AES, 256, name=key_name)
        c.activate(key_id)
        print(key_id)
        c.close()
        #return key_id
    else:
        #print('Key existes so getting the key_id')
        key_id=key_id_list[0]
        print(key_id)
        c.close()
        #return key_id

if __name__ == '__main__':
   main()
