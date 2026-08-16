# Préparation de la VM hôte (nested virtualization + disque)

Ce projet doit tourner dans une VM VirtualBox. Cette VM elle-même
héberge des VM imbriquées (Vagrant/VirtualBox pour p1 et p2), ce qui
nécessite d'activer la virtualisation imbriquée et de disposer de
suffisamment d'espace disque. Toutes les commandes ci-dessous
s'exécutent **sur la machine hôte physique**, VM éteinte, sauf mention
contraire.

## 1. Éteindre la VM proprement

Depuis un terminal dans la VM :

```bash
sudo poweroff
```

## 2. Activer la virtualisation imbriquée (nested VT-x/AMD-V)

Sur l'hôte :

```bash
VBoxManage list vms                              # repérer le nom exact de la VM
VBoxManage modifyvm "<NOM_VM>" --nested-hw-virt on
VBoxManage modifyvm "<NOM_VM>" --memory 6144      # RAM en Mo (6 Go mini recommandé)
VBoxManage modifyvm "<NOM_VM>" --cpus 4           # 2 CPU minimum, 4 conseillé
```

## 3. Agrandir le disque virtuel (.vdi)

Sur l'hôte :

```bash
VBoxManage list hdds                              # repérer "Location:" du .vdi de la VM
VBoxManage modifymedium disk "/chemin/exact/vers/le/disque.vdi" --resize 40960
```

`40960` = taille cible en **Mo** (ici 40 Go). Ne fonctionne que sur un
disque au format VDI en allocation dynamique.

## 4. Étendre la partition et le système de fichiers (dans la VM)

Une fois la VM redémarrée avec le disque agrandi, la partition et le
système de fichiers ne grandissent pas automatiquement : il faut les
étendre manuellement. Layout actuel de cette VM (table GPT) :

```
/dev/sda1  bios_grub
/dev/sda2  EFI System Partition (/boot/efi)
/dev/sda3  ext4, racine (/)          <- partition à étendre
```

Commandes à lancer **dans la VM**, après redémarrage :

```bash
sudo apt-get install -y cloud-guest-utils   # fournit growpart
sudo growpart /dev/sda 3                    # étend la partition 3 jusqu'au bout du disque
sudo resize2fs /dev/sda3                    # étend le système de fichiers ext4
df -h /                                     # vérifier le nouvel espace disponible
```

## 5. Vérifier que tout est prêt

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo   # doit être > 0 (nested virt active)
free -h                              # RAM disponible
df -h /                              # espace disque disponible
```
