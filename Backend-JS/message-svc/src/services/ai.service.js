const { Groq } = require("groq-sdk");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require("fs");

class AIService {
  constructor() {
    this.groq = new Groq({
      apiKey: process.env.GROQ_API_KEY,
    });
    this.gemini = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

    // Initialize model configurations
    this.groqPrimaryModel = "mixtral-8x7b-32768";
    this.groqFallbackModel = "llama2-70b-4096";
    this.geminiModel = "gemini-1.5-pro-vision-latest";

    // Add rate limiting configuration
    this.rateLimitConfig = {
      maxRetries: 3,
      initialDelay: 1000, // 1 second
      maxDelay: 10000, // 10 seconds
      backoffFactor: 2, // Exponential backoff multiplier
    };
  }

  async processImageForCropDisease(
    imageBuffer,
    preferredLanguage,
    location,
    weather,
    context = {}
  ) {
    try {
      const model = this.gemini.getGenerativeModel({
        model: this.geminiModel,
        generationConfig: {
          temperature: 0.7,
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
        },
      });

      const contextPrompt = context.currentTopic
        ? `Previous context: ${context.currentTopic}
           Previously identified issues: ${
             context.identifiedIssues?.join(", ") || "None"
           }
           Previous solutions suggested: ${
             context.suggestedSolutions?.join(", ") || "None"
           }\n\n`
        : "";

      const prompt = {
        contents: [
          {
            role: "user",
            parts: [
              {
                text: `${contextPrompt}As an agricultural expert, analyze this crop image and provide:
1. Disease identification (if any)
2. Detailed explanation of the condition
3. Treatment recommendations
4. Preventive measures

Consider the following environmental factors:
- Location: ${location.lat}, ${location.lon}
- Temperature: ${weather.temperature}°C
- Humidity: ${weather.humidity}%

Please structure your response clearly with headings and bullet points.
Provide the response in ${preferredLanguage}.`,
              },
              {
                inlineData: {
                  mimeType: "image/jpeg",
                  data: imageBuffer.toString("base64"),
                },
              },
            ],
          },
        ],
        tools: [
          {
            functionDeclarations: [
              {
                name: "analyzeCropDisease",
                description:
                  "Analyze crop diseases and provide recommendations",
                parameters: {
                  type: "object",
                  properties: {
                    disease: {
                      type: "string",
                      description: "Name of the identified disease",
                    },
                    severity: {
                      type: "string",
                      description: "Severity level of the disease",
                    },
                    treatments: {
                      type: "array",
                      items: { type: "string" },
                      description: "List of recommended treatments",
                    },
                    prevention: {
                      type: "array",
                      items: { type: "string" },
                      description: "List of preventive measures",
                    },
                  },
                  required: ["disease", "severity", "treatments", "prevention"],
                },
              },
            ],
          },
        ],
      };

      const result = await model.generateContent(prompt);
      const response = await result.response;

      if (!response.text()) {
        throw new Error("No response generated from the model");
      }

      return response.text();
    } catch (error) {
      console.error("Error in image processing:", error);

      // Try with fallback Groq model for text analysis if image processing fails
      try {
        const fallbackPrompt = `Based on the environmental conditions:
        - Location: ${location.lat}, ${location.lon}
        - Temperature: ${weather.temperature}°C
        - Humidity: ${weather.humidity}%
        
        Provide general crop disease prevention advice and best practices for these conditions.
        Include information about common diseases in this climate and their prevention.
        
        Please provide the response in ${preferredLanguage}.`;

        const fallbackResponse = await this.groq.chat.completions.create({
          messages: [
            {
              role: "system",
              content:
                "You are an agricultural expert providing advice about crop diseases and prevention.",
            },
            {
              role: "user",
              content: fallbackPrompt,
            },
          ],
          model: this.groqPrimaryModel,
          temperature: 0.7,
          max_tokens: 2048,
        });

        return `Note: Image analysis failed. Providing general advice based on environmental conditions:\n\n${fallbackResponse.choices[0]?.message?.content}`;
      } catch (fallbackError) {
        console.error("Fallback response failed:", fallbackError);
        throw new Error(
          "Failed to process crop image and generate fallback response"
        );
      }
    }
  }

  async getChatResponse(
    messages,
    preferredLanguage,
    location,
    weather,
    context = {}
  ) {
    let retryCount = 0;
    let delay = this.rateLimitConfig.initialDelay;

    while (retryCount <= this.rateLimitConfig.maxRetries) {
      try {
        // Extract key information from previous messages for context
        const previousContext = this._extractContextFromMessages(messages);

        // Create a conversation context from previous messages
        const conversationContext = messages
          .map(
            (msg) =>
              `${msg.role === "user" ? "Human" : "Assistant"}: ${msg.content}`
          )
          .join("\n");

        const systemPrompt = `You are an agricultural expert AI assistant. You must maintain conversation context and provide responses that directly relate to the ongoing discussion about farming and crops.

Current conversation context:
${conversationContext}

Previous context summary:
${context.currentTopic ? `Current topic: ${context.currentTopic}` : ""}
${
  context.identifiedIssues?.length
    ? `Identified issues: ${context.identifiedIssues.join(", ")}`
    : ""
}
${
  context.suggestedSolutions?.length
    ? `Suggested solutions: ${context.suggestedSolutions.join(", ")}`
    : ""
}

Environmental context:
- Location: ${location.lat}, ${location.lon}
- Temperature: ${weather.temperature}°C
- Humidity: ${weather.humidity}%

Important instructions:
1. ALWAYS read and consider the previous messages in the conversation
2. Provide responses that directly address the user's current question while maintaining context
3. If discussing a problem mentioned earlier (like plant diseases), refer back to it
4. Use consistent formatting:
   - Use ** for bold text
   - Use * for bullet points
   - Use numbered lists for steps
5. Structure your responses with clear sections
6. Stay focused on the current agricultural topic being discussed

Focus areas:
- Disease identification and treatment
- Pest management
- Plant health diagnosis
- Treatment recommendations
- Preventive measures

Provide your response in ${preferredLanguage}.`;

        const cleanedMessages = [
          {
            role: "system",
            content: systemPrompt,
          },
          // Include all messages for context
          ...messages.map((msg) => ({
            role: msg.role,
            content: msg.content,
          })),
        ];

        const completion = await this.groq.chat.completions.create({
          messages: cleanedMessages,
          model: this.groqPrimaryModel,
          temperature: 0.7,
          max_tokens: 2048,
        });

        const response = completion.choices[0]?.message?.content;

        // Update context based on the new response
        const updatedContext = this._updateContext(
          context,
          messages[messages.length - 1].content,
          response
        );

        return {
          response,
          context: updatedContext,
        };
      } catch (error) {
        if (error.response?.status === 429) {
          retryCount++;

          if (retryCount <= this.rateLimitConfig.maxRetries) {
            // Calculate next delay with exponential backoff
            delay = Math.min(
              delay * this.rateLimitConfig.backoffFactor,
              this.rateLimitConfig.maxDelay
            );

            console.log(
              `Rate limit hit, retrying in ${delay}ms (attempt ${retryCount})`
            );
            await new Promise((resolve) => setTimeout(resolve, delay));
            continue;
          }
        }
        throw error;
      }
    }
    throw new Error("Max retries exceeded for rate limit");
  }

  _extractContextFromMessages(messages) {
    // Extract key information from previous messages
    const context = {
      topics: new Set(),
      issues: new Set(),
      solutions: new Set(),
    };

    messages.forEach((msg) => {
      const content = msg.content.toLowerCase();

      // Identify topics
      if (content.includes("disease") || content.includes("pest")) {
        context.topics.add("plant health");
      }
      if (content.includes("fertilizer") || content.includes("nutrient")) {
        context.topics.add("plant nutrition");
      }

      // Extract issues and solutions (basic implementation)
      if (msg.role === "assistant") {
        const lines = content.split("\n");
        lines.forEach((line) => {
          if (line.includes("problem:") || line.includes("issue:")) {
            context.issues.add(line.split(":")[1].trim());
          }
          if (line.includes("solution:") || line.includes("recommendation:")) {
            context.solutions.add(line.split(":")[1].trim());
          }
        });
      }
    });

    return {
      topics: Array.from(context.topics),
      issues: Array.from(context.issues),
      solutions: Array.from(context.solutions),
    };
  }

  _updateContext(oldContext, userMessage, aiResponse) {
    const context = { ...oldContext };

    // Update current topic based on user message
    const topics = this._extractTopics(userMessage);
    if (topics.length > 0) {
      context.currentTopic = topics[0];
    }

    // Extract issues and solutions from AI response
    const { issues, solutions } = this._extractIssuesAndSolutions(aiResponse);

    // Update context with new information
    context.identifiedIssues = [
      ...new Set([...(context.identifiedIssues || []), ...issues]),
    ];
    context.suggestedSolutions = [
      ...new Set([...(context.suggestedSolutions || []), ...solutions]),
    ];

    // Store last context for reference
    context.lastContext = aiResponse;

    return context;
  }

  _extractTopics(text) {
    const topics = [];
    const keywords = {
      "plant health": ["disease", "pest", "symptoms", "spots", "wilting"],
      "plant nutrition": ["fertilizer", "nutrient", "deficiency", "feeding"],
      irrigation: ["water", "irrigation", "moisture", "drought"],
      "soil management": ["soil", "ph", "texture", "organic matter"],
    };

    for (const [topic, words] of Object.entries(keywords)) {
      if (words.some((word) => text.toLowerCase().includes(word))) {
        topics.push(topic);
      }
    }

    return topics;
  }

  _extractIssuesAndSolutions(text) {
    const issues = [];
    const solutions = [];

    // Split text into lines
    const lines = text.split("\n");

    lines.forEach((line) => {
      const lowerLine = line.toLowerCase();

      // Extract issues
      if (
        lowerLine.includes("problem:") ||
        lowerLine.includes("issue:") ||
        lowerLine.includes("disease:")
      ) {
        issues.push(line.split(":")[1]?.trim());
      }

      // Extract solutions
      if (
        lowerLine.includes("solution:") ||
        lowerLine.includes("treatment:") ||
        lowerLine.includes("recommendation:") ||
        lowerLine.includes("prevent:")
      ) {
        solutions.push(line.split(":")[1]?.trim());
      }
    });

    return {
      issues: issues.filter(Boolean),
      solutions: solutions.filter(Boolean),
    };
  }
}

module.exports = new AIService();
