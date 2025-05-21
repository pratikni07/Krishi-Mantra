const { Groq } = require("groq-sdk");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require("fs");

class AIService {
  constructor() {
    this.groq = new Groq({
      apiKey: process.env.GROQ_API_KEY || "",
    });
    this.geminiApiKeys = process.env.GEMINI_API_KEY
      ? process.env.GEMINI_API_KEY.split(",").map((key) => key.trim())
      : [];

    this.currentGeminiKeyIndex = 0;
    this.geminiFailureCount = 0;
    this.geminiCircuitOpen = false;
    this.geminiLastFailure = null;
    this.geminiResetTimeout = null;

    this.initializeGeminiClient();

    // Set health check interval
    this.healthCheckInterval = setInterval(
      () => this.checkGeminiHealth(),
      5 * 60 * 1000
    ); // Check every 5 minutes

    // Initialize model configurations with latest available models
    this.groqPrimaryModel = "llama3-70b-8192"; // Top tier model
    this.groqFallbackModel = "llama3-8b-8192"; // Lightweight fallback
    this.geminiModel = "gemini-1.5-pro-vision-latest";

    this.rateLimitConfig = {
      maxRetries: 3,
      initialDelay: 1000,
      maxDelay: 10000,
      backoffFactor: 2,
    };
  }

  initializeGeminiClient() {
    try {
      if (this.geminiApiKeys.length === 0) {
        console.error("No Gemini API keys available");
        return;
      }

      const currentKey = this.geminiApiKeys[this.currentGeminiKeyIndex];
      console.log(
        `Initializing Gemini client with API key index: ${this.currentGeminiKeyIndex}`
      );

      this.googleGenAI = new GoogleGenerativeAI(currentKey);

      // Updated model name from gemini-pro-vision to gemini-1.5-pro-vision
      this.geminiModel = this.googleGenAI.getGenerativeModel({
        model: "gemini-1.5-pro-vision",
        generationConfig: {
          temperature: 0.4,
          topP: 0.95,
          topK: 40,
        },
      });

      console.log("Gemini model initialized successfully");

      // Reset failure tracking on successful initialization
      this.geminiFailureCount = 0;
      this.geminiCircuitOpen = false;
    } catch (error) {
      console.error("Failed to initialize Gemini client:", error);
      this.rotateGeminiApiKey();
    }
  }

  rotateGeminiApiKey() {
    if (this.geminiApiKeys.length <= 1) {
      console.warn("Only one Gemini API key available, cannot rotate");
      return false;
    }

    const oldIndex = this.currentGeminiKeyIndex;
    this.currentGeminiKeyIndex =
      (this.currentGeminiKeyIndex + 1) % this.geminiApiKeys.length;

    console.log(
      `Rotating Gemini API key from index ${oldIndex} to ${this.currentGeminiKeyIndex}`
    );
    this.initializeGeminiClient();
    return true;
  }

  async resetGeminiClient(retryCount = 0, maxRetries = 3) {
    // Clear any pending reset timeout
    if (this.geminiResetTimeout) {
      clearTimeout(this.geminiResetTimeout);
      this.geminiResetTimeout = null;
    }

    console.log(
      `Attempting to reset Gemini client (attempt ${
        retryCount + 1
      }/${maxRetries})`
    );

    // Try rotating to a different key first
    const keyRotated = this.rotateGeminiApiKey();

    // If we couldn't rotate (only one key), reinitialize with the same key
    if (!keyRotated) {
      this.initializeGeminiClient();
    }

    // Test the connection with a simple request
    try {
      // Simple test prompt to verify connection
      const testPrompt = "Hello, this is a connection test.";
      const testResult = await this.geminiModel.generateContent(testPrompt);

      if (testResult) {
        console.log("Gemini client reset successful, connection verified");
        // Reset failure count on successful connection
        this.geminiFailureCount = 0;
        this.geminiCircuitOpen = false;
        return true;
      }
    } catch (error) {
      console.error(
        `Gemini client connection test failed after reset (attempt ${
          retryCount + 1
        }/${maxRetries}):`,
        error.message
      );

      // If we still have retries left, try again with exponential backoff
      if (retryCount < maxRetries - 1) {
        const delay = Math.pow(2, retryCount) * 1000; // Exponential backoff: 1s, 2s, 4s, etc.
        console.log(`Will retry Gemini client reset in ${delay}ms...`);

        // Schedule next retry with backoff
        this.geminiResetTimeout = setTimeout(() => {
          this.resetGeminiClient(retryCount + 1, maxRetries).catch((err) =>
            console.error("Error in delayed Gemini client reset:", err)
          );
        }, delay);

        return false;
      }

      // If we've exhausted retries, open the circuit
      this.geminiCircuitOpen = true;
      this.geminiLastFailure = new Date();
      console.error(
        "Gemini client reset failed after maximum retries, circuit breaker opened"
      );
      return false;
    }
  }

  async checkGeminiHealth() {
    console.log("Running Gemini health check...");

    // If circuit is open, check if we should try to close it
    if (this.geminiCircuitOpen) {
      const circuitOpenDuration = Date.now() - this.geminiLastFailure;
      // Wait at least 2 minutes before trying to close circuit
      if (circuitOpenDuration > 2 * 60 * 1000) {
        console.log(
          "Attempting to close Gemini circuit breaker after timeout period"
        );
        await this.resetGeminiClient();
      }
      return;
    }

    // Otherwise, perform a routine health check
    try {
      // Make sure we have a properly initialized client
      if (
        !this.geminiModel ||
        typeof this.geminiModel.generateContent !== "function"
      ) {
        console.error(
          "Health check failed: Gemini model not properly initialized"
        );
        // Try to re-initialize the client
        this.initializeGeminiClient();
        this.geminiFailureCount++;
        return;
      }

      const testPrompt = [{ text: "Health check" }];
      const testResult = await this.geminiModel.generateContent(testPrompt);

      if (testResult && testResult.response) {
        console.log("Gemini connection health check passed");
        // Reset failure counters on success
        this.geminiFailureCount = 0;
      } else {
        throw new Error("Health check returned empty response");
      }
    } catch (error) {
      console.error("Gemini connection health check failed:", error.message);
      this.geminiFailureCount++;

      // If we have consecutive failures, reset the client
      if (this.geminiFailureCount >= 2) {
        console.log(
          "Multiple consecutive health check failures, resetting Gemini client"
        );
        await this.resetGeminiClient();
      }
    }
  }

  handleConnectionError(error) {
    // Increment failure count
    this.geminiFailureCount++;

    // Check if it's a retriable connection error
    const isConnectionReset =
      error.code === "ECONNRESET" ||
      error.message?.includes("ECONNRESET") ||
      error.message?.includes("socket hang up") ||
      error.message?.includes("connection reset");

    const isTimeout =
      error.message?.includes("timeout") ||
      error.message?.includes("timed out");

    // Log detailed error information
    console.error("AI service connection error:", {
      message: error.message,
      code: error.code,
      isConnectionReset,
      isTimeout,
      failureCount: this.geminiFailureCount,
      stack: error.stack?.split("\n")[0],
    });

    // If we have too many failures or a non-retriable error, open the circuit
    if (this.geminiFailureCount >= 5 || (!isConnectionReset && !isTimeout)) {
      this.geminiCircuitOpen = true;
      this.geminiLastFailure = new Date();
      console.error(
        "Opening circuit breaker due to multiple failures or non-retriable error"
      );

      // Set timeout to try closing circuit after cooling period
      setTimeout(() => {
        this.resetGeminiClient().catch((err) =>
          console.error("Error in timed circuit reset:", err)
        );
      }, 2 * 60 * 1000); // 2 minute cooling period
    }

    // Return whether this error is retriable
    return {
      isRetriable: isConnectionReset || isTimeout,
      isConnectionReset,
      isTimeout,
    };
  }

  async processImageForCropDisease(base64Image, chatId, messageText = "") {
    // If circuit is open, check if we should try to close it
    if (this.geminiCircuitOpen) {
      const circuitOpenDuration = Date.now() - this.geminiLastFailure;
      if (circuitOpenDuration < 1 * 60 * 1000) {
        // 1 minute cooling period
        throw new Error(
          "AI service temporarily unavailable due to connection issues. Please try again later."
        );
      } else {
        // Try to close the circuit if cooling period has passed
        await this.resetGeminiClient();
        if (this.geminiCircuitOpen) {
          throw new Error(
            "AI service connection could not be established. Please try again later."
          );
        }
      }
    }

    let retryCount = 0;
    const maxRetries = Math.min(this.geminiApiKeys.length * 2, 6);
    let lastError = null;

    // Use a loop for retry logic
    while (retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          // Add increasing delay between retries with jitter
          const baseDelay = Math.pow(2, retryCount - 1) * 500; // 500ms, 1s, 2s, 4s...
          const jitter = Math.floor(Math.random() * 500); // Add up to 500ms of random jitter
          const delay = baseDelay + jitter;

          console.log(
            `Retry #${retryCount} for image processing in ${delay}ms`
          );
          await new Promise((resolve) => setTimeout(resolve, delay));
        }

        // Create a timeout promise
        const timeoutDuration = 30000; // 30 seconds
        const timeoutPromise = new Promise((_, reject) => {
          setTimeout(
            () => reject(new Error("Request timed out after 30 seconds")),
            timeoutDuration
          );
        });

        // Prepare image data
        const imageData = {
          inlineData: {
            data: base64Image,
            mimeType: "image/jpeg",
          },
        };

        // Prepare prompt with additional context
        const prompt = [
          {
            text: `I need you to analyze this crop image and provide detailed information. ${
              messageText ? 'The user says: "' + messageText + '"' : ""
            } 
            
Please identify:
1. The crop in the image
2. Any diseases, pests, or nutritional deficiencies visible
3. Detailed explanation of the identified issues
4. Recommended treatment options with specific product names when available
5. Preventive measures for future management

Include environmental factors that might affect the diagnosis.
Format your response clearly with headings and bullet points for easy reading.`,
          },
          imageData,
        ];

        // Race between model request and timeout
        const modelResponsePromise = this.geminiModel.generateContent(prompt);
        const result = await Promise.race([
          modelResponsePromise,
          timeoutPromise,
        ]);

        if (!result?.response?.text()) {
          throw new Error("Empty response from Gemini API");
        }

        // Reset failure count on success
        this.geminiFailureCount = 0;

        // Return successful response
        return result.response.text();
      } catch (error) {
        lastError = error;
        console.error(
          `Error in image processing (attempt ${retryCount + 1}/${
            maxRetries + 1
          }):`,
          error.message
        );

        // Check if error is related to quota or rate limit
        if (
          error.message?.includes("quota") ||
          error.message?.includes("rate limit") ||
          error.message?.includes("429")
        ) {
          console.log("Quota or rate limit error detected, rotating API key");
          const didRotate = this.rotateGeminiApiKey();
          if (!didRotate) {
            // If we couldn't rotate because we only have one key, wait longer
            await new Promise((resolve) => setTimeout(resolve, 5000));
          }
          retryCount++;
          continue;
        }

        // Handle connection errors
        const { isRetriable, isConnectionReset } =
          this.handleConnectionError(error);

        if (isRetriable) {
          if (isConnectionReset) {
            // For connection reset, explicitly reset the client
            console.log(
              "Connection reset error detected, resetting Gemini client before retry"
            );
            await this.resetGeminiClient();

            // Add a cooldown period before retry
            const cooldownTime = Math.pow(2, retryCount) * 1000;
            await new Promise((resolve) => setTimeout(resolve, cooldownTime));
          }

          retryCount++;
          continue;
        }

        // Non-retriable error, break the loop
        break;
      }
    }

    // If we've exhausted all retries
    console.error("Image processing failed after maximum retries");
    throw (
      lastError || new Error("Failed to process image after multiple attempts")
    );
  }

  async processMultipleImages(images, chatId, messageText = "") {
    // If circuit is open, check if we should try to close it
    if (this.geminiCircuitOpen) {
      const circuitOpenDuration = Date.now() - this.geminiLastFailure;
      if (circuitOpenDuration < 1 * 60 * 1000) {
        // 1 minute cooling period
        throw new Error(
          "AI service temporarily unavailable due to connection issues. Please try again later."
        );
      } else {
        // Try to close the circuit if cooling period has passed
        await this.resetGeminiClient();
        if (this.geminiCircuitOpen) {
          throw new Error(
            "AI service connection could not be established. Please try again later."
          );
        }
      }
    }

    let retryCount = 0;
    const maxRetries = Math.min(this.geminiApiKeys.length * 2, 6);
    let lastError = null;

    // Use a loop for retry logic
    while (retryCount <= maxRetries) {
      try {
        if (retryCount > 0) {
          // Add increasing delay between retries with jitter
          const baseDelay = Math.pow(2, retryCount - 1) * 500; // 500ms, 1s, 2s, 4s...
          const jitter = Math.floor(Math.random() * 500); // Add up to 500ms of random jitter
          const delay = baseDelay + jitter;

          console.log(
            `Retry #${retryCount} for multiple images processing in ${delay}ms`
          );
          await new Promise((resolve) => setTimeout(resolve, delay));
        }

        // Create a timeout promise
        const timeoutDuration = 45000; // 45 seconds for multiple images
        const timeoutPromise = new Promise((_, reject) => {
          setTimeout(
            () => reject(new Error("Request timed out after 45 seconds")),
            timeoutDuration
          );
        });

        // Prepare image data
        const imagePrompts = images.map((base64Image) => ({
          inlineData: {
            data: base64Image,
            mimeType: "image/jpeg",
          },
        }));

        // Prepare prompt with additional context
        const prompt = [
          {
            text: `I need you to analyze these crop images and provide detailed information. ${
              messageText ? 'The user says: "' + messageText + '"' : ""
            } 
            
Please identify:
1. The crops in the images
2. Any diseases, pests, or nutritional deficiencies visible
3. Detailed explanation of the identified issues
4. Recommended treatment options with specific product names when available
5. Preventive measures for future management

Include environmental factors that might affect the diagnosis.
Format your response clearly with headings and bullet points for easy reading.

If there are multiple images, please analyze each one separately with clear sections for each image.`,
          },
          ...imagePrompts,
        ];

        // Race between model request and timeout
        const modelResponsePromise = this.geminiModel.generateContent(prompt);
        const result = await Promise.race([
          modelResponsePromise,
          timeoutPromise,
        ]);

        if (!result?.response?.text()) {
          throw new Error("Empty response from Gemini API");
        }

        // Reset failure count on success
        this.geminiFailureCount = 0;

        // Return successful response
        return result.response.text();
      } catch (error) {
        lastError = error;
        console.error(
          `Error in multiple images processing (attempt ${retryCount + 1}/${
            maxRetries + 1
          }):`,
          error.message
        );

        // Check if error is related to quota or rate limit
        if (
          error.message?.includes("quota") ||
          error.message?.includes("rate limit") ||
          error.message?.includes("429")
        ) {
          console.log("Quota or rate limit error detected, rotating API key");
          const didRotate = this.rotateGeminiApiKey();
          if (!didRotate) {
            // If we couldn't rotate because we only have one key, wait longer
            await new Promise((resolve) => setTimeout(resolve, 5000));
          }
          retryCount++;
          continue;
        }

        // Handle connection errors
        const { isRetriable, isConnectionReset } =
          this.handleConnectionError(error);

        if (isRetriable) {
          if (isConnectionReset) {
            // For connection reset, explicitly reset the client
            console.log(
              "Connection reset error detected, resetting Gemini client before retry"
            );
            await this.resetGeminiClient();

            // Add a cooldown period before retry
            const cooldownTime = Math.pow(2, retryCount) * 1000;
            await new Promise((resolve) => setTimeout(resolve, cooldownTime));
          }

          retryCount++;
          continue;
        }

        // Non-retriable error, break the loop
        break;
      }
    }

    // If we've exhausted all retries
    console.error("Multiple images processing failed after maximum retries");
    throw (
      lastError || new Error("Failed to process images after multiple attempts")
    );
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

        // Create a condensed conversation history that focuses on agriculture topics
        const condensedHistory = this._createCondensedHistory(messages);

        const systemPrompt = `You are an agricultural expert AI assistant specialized in farming, crops, plant diseases, and agricultural practices. You must maintain conversation context and provide responses that directly relate to the ongoing discussion.

Previous conversation summary:
${condensedHistory}

Current context:
${
  context.currentTopic
    ? `- Current topic: ${context.currentTopic}`
    : "- No specific topic yet"
}
${
  context.identifiedIssues?.length
    ? `- Identified issues: ${context.identifiedIssues.join(", ")}`
    : ""
}
${
  context.suggestedSolutions?.length
    ? `- Suggested solutions: ${context.suggestedSolutions.join(", ")}`
    : ""
}

Environmental context:
- Location: ${location.lat}, ${location.lon}
- Temperature: ${weather.temperature}°C
- Humidity: ${weather.humidity}%

Important instructions:
1. ALWAYS reference previous messages and maintain continuity in your responses
2. Provide detailed, actionable agricultural advice
3. If the user mentions specific crops or issues, focus your advice on those
4. Structure responses with clear sections and bullet points
5. Include scientific explanations and practical solutions
6. Refer back to previously identified issues if relevant to the current question

Focus on agricultural topics:
- Crop cultivation techniques and best practices
- Disease identification and treatment
- Pest management
- Plant health diagnosis
- Soil management and improvement strategies
- Irrigation and water management
- Sustainable and organic farming methods
- Seasonal farming advice

Respond in ${preferredLanguage}.`;

        const cleanedMessages = [
          {
            role: "system",
            content: systemPrompt,
          },
          // Include all messages for context, but limit total token count
          ...this._getLimitedMessages(messages, 15),
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
        } else if (
          error.status === 400 &&
          error.error?.error?.code === "model_decommissioned"
        ) {
          console.error("Model error:", error.error?.error?.message);

          // Try with fallback model
          console.log(`Trying fallback model: ${this.groqFallbackModel}`);
          try {
            const systemPrompt = `You are an agricultural expert AI assistant. Provide helpful farming advice.`;

            const completion = await this.groq.chat.completions.create({
              messages: [
                { role: "system", content: systemPrompt },
                {
                  role: "user",
                  content: messages[messages.length - 1].content,
                },
              ],
              model: this.groqFallbackModel,
              temperature: 0.7,
              max_tokens: 2048,
            });

            const response = completion.choices[0]?.message?.content;
            return {
              response,
              context: context,
            };
          } catch (fallbackError) {
            console.error("Fallback model also failed:", fallbackError);
            throw new Error(
              "All available models failed to generate a response"
            );
          }
        }
        throw error;
      }
    }
    throw new Error("Max retries exceeded for rate limit");
  }

  _getLimitedMessages(messages, maxMessages = 15) {
    // If messages are fewer than the max, return all
    if (messages.length <= maxMessages) {
      return messages;
    }

    // Otherwise get the most recent messages, but always include the first system message if present
    const recentMessages = messages.slice(-maxMessages);

    // If first message was a system message and got cut off, add it back
    if (
      messages.length > maxMessages &&
      messages[0].role === "system" &&
      recentMessages[0].role !== "system"
    ) {
      return [messages[0], ...recentMessages];
    }

    return recentMessages;
  }

  _createCondensedHistory(messages) {
    // Skip if there are fewer than 3 messages
    if (messages.length < 3) {
      return "New conversation about agriculture.";
    }

    // Create a simplified history, focusing on agricultural topics
    let condensed = [];

    messages.forEach((msg, index) => {
      // Skip system messages
      if (msg.role === "system") return;

      const content = msg.content.toLowerCase();

      // Check if message contains agricultural keywords
      const isAgriRelated = this._isAgricultureRelated(content);

      if (isAgriRelated || index >= messages.length - 3) {
        const shortContent =
          msg.content.length > 100
            ? msg.content.substring(0, 100) + "..."
            : msg.content;

        condensed.push(
          `${msg.role === "user" ? "Human" : "Assistant"}: ${shortContent}`
        );
      }
    });

    // Only keep the last 5 interactions for brevity
    if (condensed.length > 5) {
      condensed = condensed.slice(-5);
    }

    return condensed.join("\n");
  }

  _isAgricultureRelated(text) {
    const keywords = [
      "crop",
      "farm",
      "plant",
      "soil",
      "harvest",
      "seed",
      "fertilizer",
      "pesticide",
      "irrigation",
      "disease",
      "pest",
      "weed",
      "organic",
      "agriculture",
      "yield",
      "growth",
      "nutrient",
      "moisture",
    ];

    return keywords.some((word) => text.includes(word));
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
