package main

import (
	"context"

	"github.com/redis/go-redis/v9"
)

var ctx = context.Background()

type Hub struct {
	Clients     map[*Client]bool
	Broadcast   chan []byte
	Register    chan *Client
	Unregister  chan *Client
	RedisClient *redis.Client
}

func NewHub() *Hub {
	return &Hub{
		Clients:    make(map[*Client]bool),
		Broadcast:  make(chan []byte),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
	}
}

func (h *Hub) RedisSubscribe(redisClient *redis.Client) {
	pubsub := redisClient.Subscribe(ctx, "chat")
	ch := pubsub.Channel()
	for msg := range ch {
		// Broadcast to all connected clients
		h.Broadcast <- []byte(msg.Payload)
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.Clients[client] = true
		case client := <-h.Unregister:
			if _, ok := h.Clients[client]; ok {
				delete(h.Clients, client)
				close(client.Send)
			}
		case message := <-h.Broadcast:
			// Publish to Redis
			if h.RedisClient != nil {
				h.RedisClient.Publish(ctx, "chat", message)
			}
			for client := range h.Clients {
				select {
				case client.Send <- message:
				default:
					delete(h.Clients, client)
					close(client.Send)
				}
			}
		}
	}
}
