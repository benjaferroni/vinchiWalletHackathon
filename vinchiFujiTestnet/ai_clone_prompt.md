# Prompt de contexto: Protocolo "Vinchi" (Synthetic Future Yield)

**Contexto para la IA:**
Tu objetivo es actuar como un Desarrollador Web3 Senior experto en DeFi y crear desde cero un protocolo completo que llamaremos "Vinchi". Este protocolo permite a los usuarios depositar una stablecoin (USDm) y recibir un token de recibo (USDv) **que representa inmediatamente su capital más el rendimiento proyectado a futuro** (ej. 103% de lo depositado).

Deberás usar **Foundry** para los Smart Contracts y **Vanilla JS, HTML y CSS** interactuando con Ethers.js para el Frontend.

A continuación, la arquitectura exacta que debes programar:

## 1. Arquitectura de Smart Contracts (Directorio `src/`)

Debes crear 4 contratos modulares. Usa `OpenZeppelin` para los estándares ERC-20 y ERC-4626.

### A. [USDm.sol](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/src/USDm.sol) (Activo Base)
- Un token ERC-20 estándar puro.
- Representa la stablecoin que los usuarios depositarán.
- Incluye una función `mint` libre o un grifo (faucet) integrado para facilitar las pruebas.

### B. [USDmY.sol](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/src/USDmY.sol) (Bóveda de Rendimiento - ERC-4626)
- Implementa el estándar `ERC4626` de OpenZeppelin.
- **Activo subyacente:** El contrato `USDm` creado anteriormente.
- **Función Clave:** Crea una función `injectYield(uint256 amount)` que haga `transferFrom` desde el `msg.sender` hacia este contrato. Esto inyectará capital externo a la bóveda, inflando el valor subyacente de cada *share* emitido para todos los depositantes.

### C. [USDv.sol](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/src/USDv.sol) (Token Nominal Futuro)
- Un token ERC-20 estándar que hereda de `Ownable`.
- Representa el dinero futuro que el usuario visualiza e interactúa.
- Al heredar de `Ownable`, el dueño será el contrato `Manager` (ver abajo).
- Sólo expone dos funciones con el modificador `onlyOwner`: `mint(address to, uint256 amount)` y `burn(address from, uint256 amount)`.

### D. [USDManager.sol](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/src/USDManager.sol) (El Orquestador - Core Protocol)
Este es el cerebro del protocolo. 
- Almacena referencias inmutables a `USDm` y `USDmY`.
- En su constructor, debe instanciar y desplegar el contrato `USDv` y aprobar a `USDmY` para gastar el `USDm` del Manager infinitamente.
- **Función 1: `depositUSDm(uint256 amount)`**
  1. Extrae `amount` de `USDm` del usuario al Manager (`transferFrom`).
  2. Deposita ese `USDm` en el vault `USDmY` bajo el nombre del Manager, recibiendo *shares*.
  3. Calcula el valor futuro asumiendo un riesgo/rendimiento predeterminado de **3% (300 bps)**. Fórmula requerida: `futureValue = sharesMinted + ((sharesMinted * 300) / 10000)`.
  4. Minta la cantidad exacta de `futureValue` en `USDv` y la envía al usuario. (El sistema ahora es subcolateralizado en un 3% hasta que se genere yield).
- **Función 2: `claimYield(uint256 amountUSDv)`**
  1. Quema la entrada de `USDv` del usuario.
  2. Revierte la matemática exacta: `sharesToRedeem = (amountUSDv * 10000) / 10300`.
  3. Hace un `redeem` de esos shares llamando a la bóveda `USDmY`.
  4. Transfiere todo el `USDm` obtenido físicamente devuelta al usuario.

## 2. Entorno de Pruebas y Scripts (Directorios `test/` y `script/`)

- Configura un [foundry.toml](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/foundry.toml) base.
- **`DeployUSDProtocol.s.sol`**: Script de despliegue que construya `USDm`, `USDmY` y finalmente el `USDManager`.
- **`USDProtocol.t.sol`**: Test esencial en Solidity. Debe comprobar estrictamente que:
  1. Si deposito 100 USDm, recibo exactamente 103 USDv.
  2. Si inmediatamente hago `claimYield(103)`, el contrato recalcula y me devuelve exactamente 100 USDm (prevención de extracción prematura simulada).
  3. Si un tercero llama a `injectYield(3)` en el vault (simulando 1 mes) y *luego* llamo al `claimYield(103)`, me devuelve exitosamente los 103 USDm que mi saldo prometía.

## 3. Arquitectura del Frontend (Directorio `frontend/`)

Crea una interfaz que demuestre el principal gancho de experiencia del usuario:
- Archivos puros: [index.html](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/frontend/index.html), [styles.css](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/frontend/styles.css), [app.js](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/frontend/app.js) y [contracts.js](file:///c:/Users/abril/Documents/vinchiMegaethTestnet/frontend/contracts.js).
- Usa la lógica conectada en `Ethers.js` v5 o v6.
- Implementa módulos para conectar Metamask/Wallet.
- **Flujos clave en la UI:**
  - Mostrar los balances del usuario directamente con llamadas on-chain a `balanceOf` tanto para USDm como para USDv.
  - Implementar un input visualmente atractivo que diga: *"Deposita USDm y obtén tu Dinero del Futuro ahora"*.
  - Mostrar explícitamente la magia: *"Vas a depositar 100 USDm y tu balance será de 103 USDv al instante"*.

