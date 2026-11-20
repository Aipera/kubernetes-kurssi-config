# Todo-projektin GitOps-määritykset

Tämä repositorio sisältää Todo-projektin Kubernetes-määritykset.

Sovelluskoodi ja konttikuvien rakentaminen ovat repositoriossa:
https://github.com/Aipera/kubernetes-kurssi

## Rakenne

- `base/`: ympäristöjen yhteinen Kustomize-pohja.
- `todo-app/manifests/`: käyttöliittymän määritykset.
- `todo-backend/manifests/`: backendin ja Wikipedia CronJobin määritykset.
- `broadcaster/manifests/`: broadcasterin määritykset.
- `gke/`: GKE-resurssit ja tietokannan varmuuskopiointi.
- `overlays/staging/`: staging-ympäristön muutokset.
- `overlays/production/`: tuotantoympäristön muutokset.
- `gitops/`: Argo CD Applicationit.
- `scripts/`: repositorion alustaminen ja Argo CD:n siirtotarkistus.

## Julkaiseminen

Koodirepon main-haaran commit käynnistää konttikuvien rakentamisen ja stagingin kuvaversioiden päivityksen.

Koodirepon tagi käynnistää tuotannon julkaisun. Tuotannon Application sidotaan tämän repositorion tiettyyn committiin ja julkaistuihin konttikuviin.

Argo CD ottaa määritykset käyttöön automaattisesti.

| Application | Tehtävä | Namespace |
|---|---|---|
| todo-environments | Hallitsee ympäristöjen Applicationeja | argocd |
| todo-staging | Staging-ympäristö | staging |
| todo-project | Tuotantoympäristö | project |

Stagingin broadcaster kirjoittaa tapahtumat lokiin, eikä stagingissa ajeta tietokannan varmuuskopiointia.

Tuotannon broadcaster lähettää tapahtumat webhookiin, ja tietokanta varmuuskopioidaan ajastetusti.

Salaisuudet hallitaan klusterissa Argo CD:n ulkopuolella.
