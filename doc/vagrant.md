# vagrant corpusops setup
We provide a vagrantfile to test corpusops inside vms.

The install prefix is in ``/srv/corpusops/corpusops.bootstrap``.

## Common intruction
Make a [corpusops.bootstrap](https://github.com/corpusops/corpusops.bootstrap) clone per VM
```
git clone https://github.com/corpusops/corpusops.bootstrap vmx
```

## Setup a vagrant VM (before launching it the first time)

### Create a centos VM
Edit ``vm_centos/vagrant_config.yml`` to looks like
```yaml
CORPUSOPS_NUM: '2'
OS: centos
#ÔS_RELEASE: "7"
```

Launch the vm
```
cd vm_centos
vagrant up
```

### Create a ubuntu VM
Edit ``vm_ubuntu/vagrant_config.yml`` to looks like
```yaml
CORPUSOPS_NUM: '2'
OS: Ubuntu
#ÔS_RELEASE: xenial

```
Launch the vm
```
cd vm_ubuntu
vagrant up
```

### Create a debian VM
Edit ``vm_debian/vagrant_config.yml`` to looks like
```yaml
CORPUSOPS_NUM: '2'
OS: debian
#ÔS_RELEASE: sid

```
Launch the vm
```
cd vm_debian
vagrant up
```

### Create a VM from an existing box
Edit ``vm_customb/vagrant_config.yml`` to looks like
```yaml
BOX: acustomnameb
BOX_URI: nil
```
Launch the vm
```
cd vm_customb
vagrant up
```

### Create a box from a custom URI
Edit ``vm_customu/vagrant_config.yml`` to looks like
```yaml
BOX: acustomnameu
BOX_URI: http://super/box.box
```
Launch the vm
```
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
cd othervm
./hacking/clone.sh /path/to/othervm
$EDITOR /path/to/othervm/vagrant_config.yml
```

## Mounting the VM as a sshfs mountpoint onto the host

## INSTALL knobs
Edit ``vm_x/vagrant_config.yml`` to adapt to your convenience
```yaml
FORCE_INSTALL: 1 (or empty string)
FORCE_SYNC: 1(or empty string)
```
