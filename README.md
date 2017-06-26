A small bash script for generating ACL permissions commands:

```
Takes output of kafka-acls --list as STDIN or from a file, and outputs kafka-acls commands to be used to migrate ACLs:
acl-generator.sh --zookeeper-host <ZK>:2181 [--file <input-file>]
```
