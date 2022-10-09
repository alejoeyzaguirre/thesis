* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Urgencias" 


********************************************************************************

**************************** Usando Datos 2021 *********************************

********************************************************************************

* Treatment por comunas?
use "$raw/Internet/casen17", clear

* Nos quedamos solo con las vars relevantes:
keep comuna expc r21d r21b

* Expandimos:
expand expc

* Vemos el número total de "personas" por comuna:
gen id = _n
egen num = count(id), by(comuna)

* Colapsamos por comuna: ? Qué hago con los missing values?
collapse (count) r21d r21b 

/* Importe Base que ya fue pre-procesada en Python (ver thesis.ipynb)
use "$output/emergencies", clear

* Me quedo solo con causas relacionadas a salud mental:
keep if idcausa > 34 & idcausa <43
