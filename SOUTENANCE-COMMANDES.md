# Soutenance — Commandes

Aide-mémoire pur commandes, sans explication. Pour la théorie, voir
[SOUTENANCE-THEORIE.md](SOUTENANCE-THEORIE.md).

> Lancez p1 en premier, avant l'arrivée de l'évaluateur (10-15 min).
> Ne lancez jamais p1/p2/p3 en même temps si la RAM est juste.

---

## p1

```bash
cd p1
vagrant up
```

```bash
vagrant status
vagrant ssh amatteiS
vagrant ssh amatteiSW
vagrant ssh amatteiS -c "hostname && ip a show eth1"
vagrant ssh amatteiSW -c "hostname && ip a show eth1"
vagrant ssh amatteiS -c "sudo k3s kubectl get nodes -o wide"
```

---

## p2

```bash
cd ../p2
vagrant up
```

```bash
vagrant ssh amatteiS -c "sudo k3s kubectl get nodes -o wide"
vagrant ssh amatteiS -c "sudo k3s kubectl get all"
vagrant ssh amatteiS -c 'curl -s -H "Host: app1.com" http://localhost'
vagrant ssh amatteiS -c 'curl -s -H "Host: app2.com" http://localhost'
vagrant ssh amatteiS -c 'curl -s http://localhost'
vagrant ssh amatteiS -c "sudo k3s kubectl get ingress"
vagrant ssh amatteiS -c "sudo k3s kubectl describe ingress apps-ingress"
```

---

## p3

```bash
cd ../p3
docker ps
k3d cluster list
bash scripts/setup.sh
```

```bash
kubectl get ns
kubectl get pods -n dev
kubectl -n argocd port-forward svc/argocd-server 8080:443
```
→ navigateur : `https://localhost:8080`

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
curl http://localhost:8888/
```

### Changer de version (v1 <-> v2)

```bash
cd ..
sed -i 's/playground:v1/playground:v2/' p3/manifests/deployment.yaml
git add p3/manifests/deployment.yaml
git commit -m "bump version"
git push
kubectl -n argocd annotate application playground argocd.argoproj.io/refresh=hard --overwrite
kubectl get pods -n dev
curl http://localhost:8888/
```

---

## Nettoyage / dépannage

```bash
# arrêter une partie sans la supprimer
cd p1 && vagrant halt

# tout supprimer et repartir de zéro
cd p1 && vagrant destroy -f && rm -rf .vagrant .node-token
cd ../p2 && vagrant destroy -f && rm -rf .vagrant
k3d cluster delete iot-cluster

# état de tout
virsh -c qemu:///system list --all
k3d cluster list
docker ps -a
free -h
df -h /
```
