/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

//My includes
#include "include/headers.p4"
#include "include/parsers.p4"

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/


control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action ecmp_group(bit<14> ecmp_group_id, bit<16> num_nhops){
        //TODO 6: define the ecmp_group action, here you need to hash the 5-tuple mod num_ports and safe it in metadata
        hash(
            meta.ecmp_hash,
            HashAlgorithm.crc32,
            (bit<1>)0,
            { 
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr,
                hdr.tcp.srcPort,
                hdr.tcp.dstPort,
                hdr.ipv4.protocol
            },
            num_nhops
        );
        meta.ecmp_group_id = ecmp_group_id;
    }

    action set_nhop(macAddr_t dstAddr, egressSpec_t port) {
        //TODO 5: Define the set_nhop action. You can copy it from the previous exercise, they are the same.
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr; 
        hdr.ethernet.dstAddr = dstAddr;
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ecmp_group_to_nhop {
        //TODO 7: define the ecmp table, this table is only called when multiple hops are available
        key = {
            meta.ecmp_group_id: exact;
            meta.ecmp_hash: exact;
        }
        actions = {
            set_nhop;
            drop;
        }

        size = 256;
        default_action = drop;
    }

    table ipv4_lpm {
        //TODO 4: define the ip forwarding table
        key = {
            hdr.ipv4.dstAddr: exact;
        }

        actions = {
            set_nhop;
            ecmp_group;
            drop;
        }
        size = 256;
        default_action = drop;
    }

    apply {
        //TODO 8: implement the ingress logic: check validities, apply first table, and if needed the second table.

        /*
        1. Check if the ipv4 header was parsed (use isValid).
        2. Apply the first table.
        3. If the action ecmp_group was called during the first table apply. 
        Call the second table. 
        Note: to know which action was called during an apply you can use a switch statement and action_run
        */
        
        if(hdr.ipv4.isValid()){
            switch(ipv4_lpm.apply().action_run){
                ecmp_group: {
                    ecmp_group_to_nhop.apply();
                }
            }
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {

    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
              hdr.ipv4.hdrChecksum,
              HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;