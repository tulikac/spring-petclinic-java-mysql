package org.springframework.samples.petclinic.chat;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.samples.petclinic.model.ChatMessage;
import org.springframework.samples.petclinic.model.ChatMessage.MessageType;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.stereotype.Controller;

import io.grpc.*;
import io.grpc.examples.*;

/**
 * Created by rajeevkumarsingh on 24/07/17.
 */
@Controller
public class ChatController {

	private SimpMessagingTemplate template;

	@Autowired
	public ChatController(SimpMessagingTemplate template) {
		this.template = template;
	}

	@MessageMapping("/chat.sendMessage")
	@SendTo("/topic/public")
	public void sendMessage(@Payload ChatMessage chatMessage) {

		// publish the user's comment
		template.convertAndSend("/topic/public", chatMessage);

		// gRPC client //
		final ManagedChannel channel = ManagedChannelBuilder.forTarget("grpc-java-server.azurewebsites.net").build();

		// String name = "When is microsof ignite?";
		String name = chatMessage.getContent().toString();

		// It is up to the client to determine whether to block the call
		// Here we create a blocking stub, but an async stub,
		// or an async stub with Future are always possible.
		GreetingServiceGrpc.GreetingServiceBlockingStub stub = GreetingServiceGrpc.newBlockingStub(channel);
		GreetingServiceOuterClass.HelloRequest request = GreetingServiceOuterClass.HelloRequest.newBuilder()
				.setName(name).build();

		// Finally, make the call using the stub
		GreetingServiceOuterClass.HelloResponse response = stub.greeting(request);

		System.out.println("grpc server responded");
		System.out.println(response.toString());

		// A Channel should be shutdown before stopping the process.
		channel.shutdownNow();

		String serverResponse = response.toString();

		// set gRPC response as the chat message
		chatMessage.setContent(serverResponse);

		// Logic to add the chatbot reply here
		String message = chatMessage.getContent();
		ChatMessage computerReply = new ChatMessage();
		computerReply.setSender("Pet Clinic");
		computerReply.setType(MessageType.CHAT);
		computerReply.setContent(message);
		template.convertAndSend("/topic/public", computerReply);

		// return chatMessage;
	}

	@MessageMapping("/chat.addUser")
	@SendTo("/topic/public")
	public ChatMessage addUser(@Payload ChatMessage chatMessage, SimpMessageHeaderAccessor headerAccessor) {
		// Add username in web socket session
		headerAccessor.getSessionAttributes().put("username", chatMessage.getSender());
		return chatMessage;
	}

	public void sendComputerMessage(SimpMessagingTemplate template, String message) {
	}

	@GetMapping("/chat")
	public String processForm() {
		return "chat/chat";
	}

}
