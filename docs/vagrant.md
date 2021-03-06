# vagrant corpusops setup

## Common instructions

- The install prefix inside the VM is in ``/srv/corpusops/corpusops.bootstrap``.
- The current folder is mounted on ``/host``.
- If you want to edit files from within your host (aka from your favourite IDE), see the ``mounting`` section.
- The files of the local clone are pushed inside the VM on the first launch.
- But after, everything lives in the VM except the Vagrant file and the provision script.
- If you want to edit files, connect to the VM first or mount it !

Make a [corpusops.bootstrap](https://github.com/corpusops/corpusops.bootstrap) clone per VM
```
git clone https://github.com/corpusops/corpusops.bootstrap vmx
```

## Setup a vagrant VM (before launching it the first time)

### Create a centos VM
Before launching vagrant up, edit ``vm_centos/vagrant_config.yml`` to looks like
```yaml
OS: centos
#ÔS_RELEASE: "7"
```

Launch the vm
```
git clone https://github.com/corpusops/corpusops.bootstrap vm_centos
cd vm_centos
vagrant up
```

### Create a ubuntu VM
Before launching vagrant up, edit dit ``vm_ubuntu/vagrant_config.yml`` to looks like
```yaml
OS: Ubuntu
#ÔS_RELEASE: xenial

```
Launch the vm
```
git clone https://github.com/corpusops/corpusops.bootstrap vm_ubuntu
cd vm_ubuntu
vagrant up
```

### Create a debian VM
Before launching vagrant up, edit ``vm_debian/vagrant_config.yml`` to looks like
```yaml
OS: debian
#ÔS_RELEASE: sid

```
Launch the vm
```
git clone https://github.com/corpusops/corpusops.bootstrap vm_debian
cd vm_debian
vagrant up
```

### Create a VM from an existing box
Before launching vagrant up, edit ``vm_customb/vagrant_config.yml`` to looks like
```yaml
BOX: acustomnameb
BOX_URI: nil
```
Launch the vm
```
git clone https://github.com/corpusops/corpusops.bootstrap vm_customb
cd vm_customb
vagrant up
```

### Create a box from a custom URI
Before launching vagrant up, edit ``vm_customu/vagrant_config.yml`` to looks like
```yaml
BOX: acustomnameu
BOX_URI: http://super/box.box
```
Launch the vm
```
git clone https://github.com/corpusops/corpusops.bootstrap vm_customu
cd vm_customu
vagrant up
```

### Setup CPU / Memory
Edit ``vm_x/vagrant_config.yml`` to adapt to your convenience
```yaml
# nb allocated cpus
CPUS: 1
# memory
MEMORY: 512
# max cpu usage in pct
MAX_CPU_USAGE_PERCENT: 25
```

### Prepare the working copy from one another, to avoid recloning everything
```
cd myvl
./hacking/clone.sh /path/to/othervm
$EDITOR /path/to/othervm/vagrant_config.yml
```

## Mounting the VM as a sshfs mountpoint onto the host
### Helpers
We made helpers to make the tedious work of using sshfs over an alternate config more straighforward.<br/>
Those scripts can be called directly, without. any argument

- ``hacking/vagrant/sshgen.sh``, Generates ``sshconfig``.
- ``hacking/vagrant/mount.sh``, Mount the VM inside ``./mountpoint``. (call sshgen.sh automatically)
- ``hacking/vagrant/umount.sh``, Umount the sshfs mountpoint.
- ``hacking/vagrant/ssh.sh``, connect to the VM using SSH. This one can take arguments that will be appened, to behave like a ssh client. (call sshgen.sh automatically)


Eg, to mount the vm
```
cd myvm
vagrant up
hacking/vagrant/mount.sh
```

### Manually
- You must install sshfs onto your host
- Generate a local sshconfig to access your VM
```
vagrant ssh-config \
    | sed \
        -e "s/User .*/User root/g" \
        -e "s/Host .*/Host vagrant/g" > sshconfig
```
This will result in ``./sshconfig`` like
```
Host vagrant
  HostName 127.0.0.1
  User root
  Port 2200
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /home/u/vm/.vagrant/machines/corpusops2-1/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL

```

Then, each time you want to mount it, issue:
```
if [ ! -e mountpoint ];then mkdir mountpoint;fi
sshfs -F $(pwd)/sshconfig vagrant:/ mountpoint
```

To umount
```
fusermount -u mountpoint
```
 

## Import/Export of an exiting VM
Be careful
- Virtualenv will be reconstructed, as of it's ansible subcheckout
- Roles & playbook will be recheckouted at each VM new spawn from an exported one unless
  you use ``hacking/clone.sh`` to speed up the spawn process.
- Roles & checkouts pinnings are done via ``requirements/*.in`` files of your corpusops clone.

### Export a VM
```
cd myvm
vagrant halt -f
./hacking/vagrant/export.sh myvm
```
### Import a VM
From a file ``vm.box`` produced by export.sh
```
git clone https://github.com/corpusops/corpusops.bootstrap vmx
cd vmx
./hacking/vagrant/import.sh /path/to/myvm.box
```

### Cleaning up transient import boxes
After working a while, issue
```
vagrant box list
```

You can then remove stale import files with
```
vagrant box remove <id>
```
If the box is really stale and not in used anymore, it will be no warning before
it to be removed

## INSTALL knobs
Edit ``vm_x/vagrant_config.yml`` to adapt to your convenience
```yaml
FORCE_INSTALL: 1 (or empty string)
FORCE_SYNC: 1 (or empty string)
SKIP_INSTALL: 1 (or empty string)
SKIP_ROOTSSHKEYS_SYNC: 1 (or empty string)
```

