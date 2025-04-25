// assets/js/room_chat.js
import {Socket} from "phoenix"

const RoomChat = {
  init(roomId, userId, token) {
    // Initialize the socket with the user token
    const socket = new Socket("/socket", {params: {token: token}})
    socket.connect()
    
    // Join the room channel
    const channel = socket.channel(`room:${roomId}`, {})
    
    // DOM elements
    const messagesContainer = document.getElementById("chat-messages")
    const messageInput = document.getElementById("message-input")
    const sendButton = document.getElementById("send-message")
    const fileUploadButton = document.getElementById("file-upload")
    
    // Handle message submission
    sendButton.addEventListener("click", () => {
      const content = messageInput.value.trim()
      if (content !== "") {
        channel.push("message:new", {content: content})
          .receive("ok", () => {
            messageInput.value = ""
          })
          .receive("error", (resp) => {
            console.error("Failed to send message", resp)
          })
      }
    })
    
    // Also send on Enter key
    messageInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        sendButton.click()
      }
    })
    
    // Handle file uploads
    fileUploadButton.addEventListener("change", (e) => {
      const file = e.target.files[0]
      if (file) {
        const reader = new FileReader()
        reader.onload = (event) => {
          // Strip off the header from the data URL
          const base64Data = event.target.result.split(",")[1]
          
          channel.push("message:file", {
            file_data: base64Data,
            file_name: file.name
          })
            .receive("ok", () => {
              // Clear the file input
              fileUploadButton.value = null
            })
            .receive("error", (resp) => {
              console.error("Failed to upload file", resp)
            })
        }
        reader.readAsDataURL(file)
      }
    })
    
    // Render a message in the chat
    const renderMessage = (message) => {
      const isCurrentUser = message.user_id.toString() === userId.toString()
      const messageClass = isCurrentUser ? "self-end bg-blue-100" : "self-start bg-gray-100"
      
      let messageContent = ""
      if (message.message_type === "file") {
        messageContent = `
          <a href="${message.attachment_url}" target="_blank" class="text-blue-600 underline">
            ${message.content}
          </a>
        `
      } else {
        messageContent = message.content
      }
      
      const messageEl = document.createElement("div")
      messageEl.id = `message-${message.id}`
      messageEl.className = `max-w-3/4 rounded-lg px-4 py-2 mb-2 ${messageClass}`
      messageEl.innerHTML = `
        <div class="font-semibold text-xs text-gray-700">${message.user_name}</div>
        <div class="mt-1">${messageContent}</div>
        <div class="text-xs text-gray-500 mt-1">
          ${new Date(message.inserted_at).toLocaleTimeString()}
        </div>
      `
      
      if (isCurrentUser) {
        const deleteButton = document.createElement("button")
        deleteButton.className = "text-xs text-red-600 hover:underline ml-2"
        deleteButton.innerText = "Delete"
        deleteButton.addEventListener("click", () => {
          channel.push("message:delete", {message_id: message.id})
        })
        
        messageEl.querySelector(".text-gray-500").appendChild(deleteButton)
      }
      
      messagesContainer.appendChild(messageEl)
      // Scroll to bottom
      messagesContainer.scrollTop = messagesContainer.scrollHeight
    }
    
    // Join the channel
    channel.join()
      .receive("ok", () => {
        console.log("Joined room chat successfully")
      })
      .receive("error", (resp) => {
        console.error("Unable to join", resp)
      })
    
    // Listen for message history
    channel.on("messages:history", (payload) => {
      messagesContainer.innerHTML = ""
      payload.messages.forEach(renderMessage)
    })
    
    // Listen for new messages
    channel.on("message:new", (message) => {
      renderMessage(message)
    })
    
    // Listen for deleted messages
    channel.on("message:deleted", (payload) => {
      const messageEl = document.getElementById(`message-${payload.message_id}`)
      if (messageEl) {
        messageEl.remove()
      }
    })
    
    return channel
  }
}

export default RoomChat