# Indications Reference

## Quick Lookup

| Code | Full Name | Default Week | Preferred Estimand | Response Type |
|------|-----------|:------------:|:------------------:|:-------------:|
| `ad` | Atopic Dermatitis | 16 | NRI | binary |
| `pso` | Psoriasis | 16 | NRI | binary |
| `uc` | Ulcerative Colitis | 12 | NRI | binary |
| `ra` | Rheumatoid Arthritis | 12 | NRI | binary |
| `crswnp` | CRSwNP | 24 | — | binary |
| `psa` | Psoriatic Arthritis | 12 | NRI | binary |
| `crohns` | Crohn's Disease | 12 | NRI | binary |
| `sle` | SLE | 24 | — | binary |
| `asthma` | Asthma | 24 | — | binary |
| `copd` | COPD | 24 | — | binary |
| `ipf` | IPF | 24 | — | binary |
| `ar` | Allergic Rhinitis | 4 | — | **continuous** |

---

## Endpoints by Indication

### Atopic Dermatitis (`ad`)

**Primary endpoints:** IGA 0/1, EASI-75
**Secondary:** EASI-90

| Code | Label | Match Pattern |
|------|-------|---------------|
| `iga01` | IGA 0/1 | Contains "iga" AND ("0" or "1") |
| `easi75` | EASI-75 | Contains "easi" AND "75" |
| `easi90` | EASI-90 | Contains "easi" AND "90" |

**Key comparators:** dupilumab/Dupixent, lebrikizumab/Ebglyss, tralokinumab/Adbry, abrocitinib/Cibinqo, upadacitinib/Rinvoq

**LLM naming hint:** Use `iga01` for IGA 0/1 or vIGA-AD 0/1; `easi75` for EASI-75; `easi90` for EASI-90

---

### Psoriasis (`pso`)

**Primary endpoints:** PASI-75, PASI-90
**Secondary:** PASI-100

| Code | Label | Match Pattern |
|------|-------|---------------|
| `pasi75` | PASI-75 | Contains "pasi" AND "75" |
| `pasi90` | PASI-90 | Contains "pasi" AND "90" |
| `pasi100` | PASI-100 | Contains "pasi" AND "100" |

**Key comparators:** secukinumab/Cosentyx, ixekizumab/Taltz, risankizumab/Skyrizi, guselkumab/Tremfya, bimekizumab/Bimzelx

---

### Ulcerative Colitis (`uc`)

**Primary endpoints:** Clinical Remission, Clinical Response
**Secondary:** Endoscopic Improvement

| Code | Label | Match Pattern |
|------|-------|---------------|
| `clin_remission` | Clinical Remission | Contains "remission" but NOT "endoscop" |
| `clin_response` | Clinical Response | Contains "response" AND "clinic" |
| `endo_improvement` | Endoscopic Improvement | Contains "endoscop" AND "improv" |

**Key comparators:** adalimumab/Humira, vedolizumab/Entyvio, upadacitinib/Rinvoq, ozanimod/Zeposia, tofacitinib/Xeljanz

---

### Rheumatoid Arthritis (`ra`)

**Primary endpoints:** ACR20, ACR50

| Code | Label | Match Pattern |
|------|-------|---------------|
| `acr20` | ACR20 | Contains "acr" AND "20" |
| `acr50` | ACR50 | Contains "acr" AND "50" |

**Key comparators:** adalimumab/Humira, baricitinib/Olumiant, upadacitinib/Rinvoq, tofacitinib/Xeljanz

---

### CRSwNP (`crswnp`)

**Primary endpoints:** NPS, NCS

| Code | Label | Match Pattern |
|------|-------|---------------|
| `nps` | Nasal Polyp Score | Contains "nasal polyp score" or "nps" |
| `ncs` | Nasal Congestion Score | Contains "nasal congestion" or "ncs" |

**Key comparators:** dupilumab/Dupixent, omalizumab/Xolair, mepolizumab/Nucala

**Note:** NPS and NCS are typically reported as change from baseline (continuous), but stored as binary (responder threshold) for BNMA in some contexts.

---

### Psoriatic Arthritis (`psa`)

**Primary endpoints:** ACR50, PASI-90

| Code | Label | Match Pattern |
|------|-------|---------------|
| `acr50` | ACR50 | Contains "acr" AND "50" |
| `pasi90` | PASI-90 | Contains "pasi" AND "90" |

**Key comparators:** secukinumab/Cosentyx, ixekizumab/Taltz, guselkumab/Tremfya, upadacitinib/Rinvoq

---

### Crohn's Disease (`crohns`)

**Primary endpoints:** Clinical Remission, Clinical Response
**Secondary:** Endoscopic Response

| Code | Label | Match Pattern |
|------|-------|---------------|
| `clin_remission` | Clinical Remission | Contains "remission" but NOT "endoscop" |
| `clin_response` | Clinical Response | Contains "response" AND "clinic" |
| `endo_response` | Endoscopic Response | Contains "endoscop" AND "respon" |

**Key comparators:** adalimumab/Humira, vedolizumab/Entyvio, ustekinumab/Stelara, risankizumab/Skyrizi

---

### SLE (`sle`)

**Primary endpoints:** BICLA, SRI-4

| Code | Label | Match Pattern |
|------|-------|---------------|
| `bicla` | BICLA | Contains "bicla" |
| `sri4` | SRI-4 | Contains "sri" + "4" or "sle responder" |

**Key comparators:** belimumab/Benlysta, anifrolumab/Saphnelo

---

### Asthma (`asthma`)

**Primary endpoints:** AAER, FEV1

| Code | Label | Match Pattern |
|------|-------|---------------|
| `aaer` | Annualized Asthma Exacerbation Rate | Contains "annualized asthma exacerbation" or "aaer" |
| `fev1` | FEV1 | Contains "fev1" or "forced expiratory" |

**Key comparators:** dupilumab/Dupixent, tezepelumab/Tezspire, benralizumab/Fasenra, mepolizumab/Nucala

---

### COPD (`copd`)

**Primary endpoints:** AER, FEV1

| Code | Label | Match Pattern |
|------|-------|---------------|
| `aer` | Annualized Exacerbation Rate | Contains "annualized exacerbation" or "aer" or "exacerbation rate" |
| `fev1` | FEV1 | Contains "fev1" or "forced expiratory" |

**Key comparators:** dupilumab/Dupixent, benralizumab/Fasenra, itepekimab

---

### IPF (`ipf`)

**Primary endpoints:** FVC

| Code | Label | Match Pattern |
|------|-------|---------------|
| `fvc` | FVC | Contains "fvc" or "forced vital capacity" |

**Key comparators:** pirfenidone/Esbriet, nintedanib/Ofev

---

### Allergic Rhinitis (`ar`) — CONTINUOUS endpoints

**Primary endpoints:** TNSS
**Secondary:** rTNSS, iTNSS, TOSS, RQLQ, Nasal Congestion

| Code | Label | Match Pattern |
|------|-------|---------------|
| `tnss` | Total Nasal Symptom Score | Contains "total nasal symptom" or "tnss" (not reflective/instantaneous) |
| `rtnss` | Reflective TNSS | Contains "reflective" + ("total nasal" or "tnss") |
| `itnss` | Instantaneous TNSS | Contains "instantaneous" + ("total nasal" or "tnss") |
| `toss` | Total Ocular Symptom Score | Contains "total ocular symptom" or "toss" |
| `rqlq` | RQLQ | Contains "rqlq" or "rhinoconjunctivitis quality" |
| `nasal_congestion` | Nasal Congestion Score | Contains "nasal congestion score" |

**IMPORTANT:** These are CONTINUOUS outcomes. Extract mean change from baseline (not responder rates). Also extract SD and SE if reported.

**Key comparators:** montelukast, cetirizine, fexofenadine, intranasal corticosteroids (fluticasone, mometasone)
