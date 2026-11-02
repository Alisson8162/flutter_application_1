// Camada simples de tempo real, desacoplada do transporte.
//
// server.js registra um WebSocketServer e, para cada conexão, associa o
// socket a um rideId (via `registerConnection`). Os controllers (ex:
// rideController, locationController) chamam `broadcastToRide` sem precisar
// saber nada sobre WebSocket - isso evita dependência circular entre
// server.js e os controllers.

const rideConnections = new Map(); // rideId -> Set<ws>

function registerConnection(rideId, socket) {
  if (!rideConnections.has(rideId)) {
    rideConnections.set(rideId, new Set());
  }
  rideConnections.get(rideId).add(socket);

  socket.on('close', () => {
    const set = rideConnections.get(rideId);
    if (set) {
      set.delete(socket);
      if (set.size === 0) rideConnections.delete(rideId);
    }
  });
}

function broadcastToRide(rideId, payload) {
  const set = rideConnections.get(String(rideId));
  if (!set) return;
  const message = JSON.stringify(payload);
  for (const socket of set) {
    if (socket.readyState === socket.OPEN) {
      socket.send(message);
    }
  }
}

module.exports = { registerConnection, broadcastToRide };
