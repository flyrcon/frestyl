// assets/js/socket.js
import { Socket } from "phoenix"

// Create socket with authentication token
const token = document.querySelector("meta[name='user-token']")?.getAttribute("content")
export const socket = new Socket("/socket", { params: { token } })

// Connect to the socket server when this module is imported
socket.connect()

export default socket