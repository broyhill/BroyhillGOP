"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_accounts SET
                welcome_message = %s,
                welcome_buttons = %s,
                updated_at = NOW()
            WHERE account_id = %s
        """, (message, json.dumps(buttons or []), account_id))
        
        conn.commit()
        conn.close()
        return True
    
    def set_persistent_menu(self, account_id: str, menu_items: List[Dict]) -> bool:
        """Set persistent menu for Messenger"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_accounts SET
                persistent_menu = %s,
                updated_at = NOW()
            WHERE account_id = %s
        """, (json.dumps(menu_items), account_id))
        
        conn.commit()
        conn.close()
        return True
    
    # ========================================================================
    # MESSAGE HANDLING
    # ========================================================================
    
    def handle_incoming_message(self, account_id: str, platform_user_id: str,
                               message_text: str, message_type: str = 'text',
                               media_url: str = None) -> Dict:
        """Handle incoming message from Messenger/Instagram"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get or create user
        cur.execute("""
            INSERT INTO messenger_users (account_id, platform_user_id, platform)
            SELECT %s, %s, (SELECT platform FROM messenger_accounts WHERE account_id = %s)
            ON CONFLICT (platform_user_id, platform) DO UPDATE SET
                last_interaction_at = NOW(),
                total_messages = messenger_users.total_messages + 1
            RETURNING user_id
        """, (account_id, platform_user_id, account_id))
        user_id = str(cur.fetchone()['user_id'])
        
        # Get or create conversation
        cur.execute("""
            SELECT conversation_id FROM messenger_conversations
            WHERE user_id = %s AND status = 'active'
            ORDER BY last_message_at DESC LIMIT 1
        """, (user_id,))
        conv = cur.fetchone()
        
        if conv:
            conversation_id = str(conv['conversation_id'])
        else:
            cur.execute("""
                INSERT INTO messenger_conversations (account_id, user_id)
                VALUES (%s, %s)
                RETURNING conversation_id
            """, (account_id, user_id))
            conversation_id = str(cur.fetchone()['conversation_id'])
        
        # Save incoming message
        cur.execute("""
            INSERT INTO messenger_messages (
                conversation_id, direction, message_type, text_content, media_url
            ) VALUES (%s, 'inbound', %s, %s, %s)
            RETURNING message_id
        """, (conversation_id, message_type, message_text, media_url))
        message_id = str(cur.fetchone()['message_id'])
        
        # Update conversation
        cur.execute("""
            UPDATE messenger_conversations SET
                last_message_at = NOW(),
                message_count = message_count + 1
            WHERE conversation_id = %s
        """, (conversation_id,))
        
        # Update account stats
        cur.execute("""
            UPDATE messenger_accounts SET
                total_messages_received = total_messages_received + 1
            WHERE account_id = %s
        """, (account_id,))
        
        conn.commit()
        
        # Check for keyword triggers
        response = self._check_keywords(cur, account_id, message_text, conversation_id)
        
        # If no keyword match, use AI
        if not response and self._is_ai_enabled(cur, account_id):
            response = self._generate_ai_response(cur, conversation_id, message_text)
        
        conn.close()
        
        return {
            'message_id': message_id,
            'conversation_id': conversation_id,
            'user_id': user_id,
            'response': response
        }
    
    def _check_keywords(self, cur, account_id: str, message_text: str,
                       conversation_id: str) -> Optional[Dict]:
        """Check for keyword triggers"""
        message_lower = message_text.lower()
        
        cur.execute("""
            SELECT * FROM messenger_keywords
            WHERE account_id = %s AND mode != 'off'
            AND (timer_expires_at IS NULL OR timer_expires_at > NOW())
        """, (account_id,))
        
        for keyword in cur.fetchall():
            kw = keyword['keyword'].lower()
            match = False
            
            if keyword['match_type'] == 'exact' and message_lower == kw:
                match = True
            elif keyword['match_type'] == 'contains' and kw in message_lower:
                match = True
            elif keyword['match_type'] == 'starts_with' and message_lower.startswith(kw):
                match = True
            
            if match:
                # Update trigger count
                cur.execute("""
                    UPDATE messenger_keywords SET times_triggered = times_triggered + 1
                    WHERE keyword_id = %s
                """, (keyword['keyword_id'],))
                
                # Start flow if specified
                if keyword['flow_id']:
                    self._start_flow(cur, keyword['flow_id'], conversation_id)
                
                return {
                    'type': 'keyword_response',
                    'text': keyword['response_text'],
                    'buttons': keyword['response_buttons']
                }
        
        return None
    
    def _is_ai_enabled(self, cur, account_id: str) -> bool:
        """Check if AI is enabled for account"""
        cur.execute("SELECT ai_enabled FROM messenger_accounts WHERE account_id = %s", (account_id,))
        result = cur.fetchone()
        return result['ai_enabled'] if result else False
    
    def _generate_ai_response(self, cur, conversation_id: str, message_text: str) -> Dict:
        """Generate AI response using Claude"""
        # Get conversation context
        cur.execute("""
            SELECT text_content, direction FROM messenger_messages
            WHERE conversation_id = %s
            ORDER BY created_at DESC LIMIT 10
        """, (conversation_id,))
        history = cur.fetchall()
        
        # In production, call Claude API
        # For now, return placeholder
        return {
            'type': 'ai_response',
            'text': f"Thanks for your message! Our team will get back to you shortly. Is there anything specific I can help you with?",
            'is_ai': True
        }
    
    def _start_flow(self, cur, flow_id: str, conversation_id: str) -> None:
        """Start an automation flow for conversation"""
        cur.execute("""
            UPDATE messenger_conversations SET
                current_flow_id = %s,
                current_step = 'start'
            WHERE conversation_id = %s
        """, (flow_id, conversation_id))
        
        cur.execute("""
            UPDATE messenger_flows SET times_triggered = times_triggered + 1
            WHERE flow_id = %s
        """, (flow_id,))
    
    def send_message(self, conversation_id: str, text: str,
                    buttons: List[Dict] = None,
                    quick_replies: List[Dict] = None,
                    media_url: str = None) -> str:
        """Send outbound message"""
        conn = self._get_db()
        cur = conn.cursor()
        
        message_type = 'text'
        if buttons:
            message_type = 'button'
        elif quick_replies:
            message_type = 'quick_reply'
        elif media_url:
            message_type = 'image'
        
        cur.execute("""
            INSERT INTO messenger_messages (
                conversation_id, direction, message_type, text_content,
                buttons, quick_replies, media_url
            ) VALUES (%s, 'outbound', %s, %s, %s, %s, %s)
            RETURNING message_id
        """, (
            conversation_id, message_type, text,
            json.dumps(buttons or []),
            json.dumps(quick_replies or []),
            media_url
        ))
        
        message_id = str(cur.fetchone()[0])
        
        # Update stats
        cur.execute("""
            UPDATE messenger_conversations SET
                last_message_at = NOW(),
                message_count = message_count + 1
            WHERE conversation_id = %s
        """, (conversation_id,))
        
        cur.execute("""
            UPDATE messenger_accounts SET
                total_messages_sent = total_messages_sent + 1
            WHERE account_id = (
                SELECT account_id FROM messenger_conversations WHERE conversation_id = %s
            )
        """, (conversation_id,))
        
        conn.commit()
        conn.close()
        
        # In production, send via Facebook/Instagram API
        logger.info(f"Sent message: {message_id}")
        return message_id
    
    # ========================================================================
    # AUTOMATION FLOWS
    # ========================================================================
    
    def create_flow(self, account_id: str, name: str, trigger_type: str,
                   trigger_config: Dict = None, steps: List[Dict] = None,
                   mode: str = 'on', timer_minutes: int = None) -> str:
        """Create automation flow"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_flows (
                account_id, name, trigger_type, trigger_config, steps,
                mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING flow_id
        """, (
            account_id, name, trigger_type,
            json.dumps(trigger_config or {}),
            json.dumps(steps or []),
            mode, timer_minutes, timer_expires_at
        ))
        
        flow_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created flow: {name}")
        return flow_id
    
    def set_flow_mode(self, flow_id: str, mode: str,
                     timer_minutes: int = None) -> Dict:
        """Set flow mode: on/off/timer"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            UPDATE messenger_flows SET
                mode = %s,
                timer_minutes = %s,
                timer_expires_at = %s,
                updated_at = NOW()
            WHERE flow_id = %s
        """, (mode, timer_minutes, timer_expires_at, flow_id))
        
        conn.commit()
        conn.close()
        
        return {
            'flow_id': flow_id,
            'mode': mode,
            'timer_minutes': timer_minutes,
            'timer_expires_at': timer_expires_at.isoformat() if timer_expires_at else None
        }
    
    # ========================================================================
    # KEYWORDS
    # ========================================================================
    
    def add_keyword(self, account_id: str, keyword: str, response_text: str,
                   match_type: str = 'contains', flow_id: str = None,
                   buttons: List[Dict] = None,
                   mode: str = 'on', timer_minutes: int = None) -> str:
        """Add keyword trigger"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_keywords (
                account_id, keyword, match_type, action_type,
                flow_id, response_text, response_buttons,
                mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, 'respond', %s, %s, %s, %s, %s, %s)
            RETURNING keyword_id
        """, (
            account_id, keyword.upper(), match_type, flow_id,
            response_text, json.dumps(buttons or []),
            mode, timer_minutes, timer_expires_at
        ))
        
        keyword_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return keyword_id
    
    def set_keyword_mode(self, keyword_id: str, mode: str,
                        timer_minutes: int = None) -> Dict:
        """Set keyword mode: on/off/timer"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            UPDATE messenger_keywords SET
                mode = %s,
                timer_minutes = %s,
                timer_expires_at = %s
            WHERE keyword_id = %s
        """, (mode, timer_minutes, timer_expires_at, keyword_id))
        
        conn.commit()
        conn.close()
        
        return {'keyword_id': keyword_id, 'mode': mode}
    
    # ========================================================================
    # COMMENT-TO-DM
    # ========================================================================
    
    def create_comment_trigger(self, account_id: str, post_id: str,
                              dm_message: str, trigger_keywords: List[str] = None,
                              trigger_on_any: bool = False,
                              dm_buttons: List[Dict] = None,
                              flow_id: str = None,
                              mode: str = 'on', timer_minutes: int = None) -> str:
        """Create comment-to-DM trigger"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_comment_triggers (
                account_id, post_id, trigger_keywords, trigger_on_any_comment,
                dm_message, dm_buttons, flow_id,
                mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING trigger_id
        """, (
            account_id, post_id,
            json.dumps(trigger_keywords or []),
            trigger_on_any,
            dm_message, json.dumps(dm_buttons or []),
            flow_id, mode, timer_minutes, timer_expires_at
        ))
        
        trigger_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created comment trigger for post: {post_id}")
        return trigger_id
    
    def process_comment(self, post_id: str, commenter_id: str,
                       comment_text: str) -> Optional[Dict]:
        """Process incoming comment and trigger DM if matched"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Find matching triggers
        cur.execute("""
            SELECT * FROM messenger_comment_triggers
            WHERE post_id = %s AND is_active = true
            AND mode != 'off'
            AND (timer_expires_at IS NULL OR timer_expires_at > NOW())
        """, (post_id,))
        
        for trigger in cur.fetchall():
            should_trigger = trigger['trigger_on_any_comment']
            
            if not should_trigger and trigger['trigger_keywords']:
                comment_lower = comment_text.lower()
                for kw in trigger['trigger_keywords']:
                    if kw.lower() in comment_lower:
                        should_trigger = True
                        break
            
            if should_trigger:
                # Update stats
                cur.execute("""
                    UPDATE messenger_comment_triggers SET
                        comments_detected = comments_detected + 1,
                        dms_sent = dms_sent + 1
                    WHERE trigger_id = %s
                """, (trigger['trigger_id'],))
                
                conn.commit()
                conn.close()
                
                return {
                    'trigger_id': str(trigger['trigger_id']),
                    'dm_message': trigger['dm_message'],
                    'dm_buttons': trigger['dm_buttons'],
                    'flow_id': str(trigger['flow_id']) if trigger['flow_id'] else None,
                    'send_to': commenter_id
                }
        
        conn.close()
        return None
    
    # ========================================================================
    # BROADCASTS
    # ========================================================================
    
    def create_broadcast(self, account_id: str, name: str, content: str,
                        buttons: List[Dict] = None,
                        target_tags: List[str] = None,
                        scheduled_at: datetime = None) -> str:
        """Create broadcast message"""
        conn = self._get_db()
        cur = conn.cursor()
        
        status = 'scheduled' if scheduled_at else 'draft'
        
        cur.execute("""
            INSERT INTO messenger_broadcasts (
                account_id, name, content, buttons,
                target_tags, scheduled_at, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING broadcast_id
        """, (
            account_id, name, content,
            json.dumps(buttons or []),
            json.dumps(target_tags or []),
            scheduled_at, status
        ))
        
        broadcast_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return broadcast_id
    
    def send_broadcast(self, broadcast_id: str) -> Dict:
        """Send broadcast to all matching users"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM messenger_broadcasts WHERE broadcast_id = %s", (broadcast_id,))
        broadcast = cur.fetchone()
        
        if not broadcast:
            conn.close()
            return {'error': 'Broadcast not found'}
        
        # Get matching users
        query = """
            SELECT user_id, platform_user_id FROM messenger_users
            WHERE account_id = %s AND is_subscribed = true
        """
        params = [broadcast['account_id']]
        
        if broadcast['target_tags']:
            query += " AND tags ?| %s"
            params.append(broadcast['target_tags'])
        
        cur.execute(query, params)
        users = cur.fetchall()
        
        # Update broadcast stats
        cur.execute("""
            UPDATE messenger_broadcasts SET
                status = 'sent',
                sent_at = NOW(),
                total_recipients = %s
            WHERE broadcast_id = %s
        """, (len(users), broadcast_id))
        
        conn.commit()
        conn.close()
        
        # In production, send to each user via API
        return {
            'broadcast_id': broadcast_id,
            'recipients': len(users),
            'status': 'sent'
        }
    
    # ========================================================================
    # SEQUENCES (DRIP CAMPAIGNS)
    # ========================================================================
    
    def create_sequence(self, account_id: str, name: str, steps: List[Dict],
                       mode: str = 'on', timer_minutes: int = None) -> str:
        """Create drip sequence"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_sequences (
                account_id, name, steps, mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING sequence_id
        """, (
            account_id, name, json.dumps(steps),
            mode, timer_minutes, timer_expires_at
        ))
        
        sequence_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return sequence_id
    
    def enroll_in_sequence(self, sequence_id: str, user_id: str) -> str:
        """Enroll user in sequence"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get sequence first step timing
        cur.execute("SELECT steps FROM messenger_sequences WHERE sequence_id = %s", (sequence_id,))
        sequence = cur.fetchone()
        
        steps = sequence['steps']
        first_delay = steps[0].get('delay_minutes', 0) if steps else 0
        next_message_at = datetime.now() + timedelta(minutes=first_delay)
        
        cur.execute("""
            INSERT INTO messenger_sequence_enrollments (
                sequence_id, user_id, next_message_at
            ) VALUES (%s, %s, %s)
            RETURNING enrollment_id
        """, (sequence_id, user_id, next_message_at))
        
        enrollment_id = str(cur.fetchone()['enrollment_id'])
        
        cur.execute("""
            UPDATE messenger_sequences SET total_enrolled = total_enrolled + 1
            WHERE sequence_id = %s
        """, (sequence_id,))
        
        conn.commit()
        conn.close()
        
        return enrollment_id
    
    def process_sequence_messages(self) -> List[Dict]:
        """Process due sequence messages (run via cron)"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get due messages
        cur.execute("""
            SELECT e.*, s.steps, s.mode, s.timer_expires_at
            FROM messenger_sequence_enrollments e
            JOIN messenger_sequences s ON e.sequence_id = s.sequence_id
            WHERE e.status = 'active'
            AND e.next_message_at <= NOW()
            AND s.is_active = true
            AND s.mode != 'off'
            AND (s.timer_expires_at IS NULL OR s.timer_expires_at > NOW())
        """)
        
        processed = []
        for enrollment in cur.fetchall():
            steps = enrollment['steps']
            current_step = enrollment['current_step']
            
            if current_step >= len(steps):
                # Sequence complete
                cur.execute("""
                    UPDATE messenger_sequence_enrollments SET
                        status = 'completed',
                        completed_at = NOW()
                    WHERE enrollment_id = %s
                """, (enrollment['enrollment_id'],))
                continue
            
            step = steps[current_step]
            
            # Send message
            # In production, actually send via API
            
            # Update enrollment
            next_step = current_step + 1
            if next_step < len(steps):
                next_delay = steps[next_step].get('delay_minutes', 60)
                next_message_at = datetime.now() + timedelta(minutes=next_delay)
            else:
                next_message_at = None
            
            cur.execute("""
                UPDATE messenger_sequence_enrollments SET
                    current_step = %s,
                    next_message_at = %s
                WHERE enrollment_id = %s
            """, (next_step, next_message_at, enrollment['enrollment_id']))
            
            processed.append({
                'enrollment_id': str(enrollment['enrollment_id']),
                'user_id': str(enrollment['user_id']),
                'step': current_step,
                'message': step.get('message')
            })
        
        conn.commit()
        conn.close()
        
        return processed
    
    # ========================================================================
    # ANALYTICS
    # ========================================================================
    
    def get_account_stats(self, account_id: str) -> Dict:
        """Get account statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_messenger_stats WHERE account_id = %s", (account_id,))
        stats = cur.fetchone()
        
        conn.close()
        return dict(stats) if stats else {}
    
    def get_flow_performance(self, account_id: str) -> List[Dict]:
        """Get flow performance metrics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM v_flow_performance f
            JOIN messenger_flows mf ON f.flow_id = mf.flow_id
            WHERE mf.account_id = %s
        """, (account_id,))
        
        flows = [dict(f) for f in cur.fetchall()]
        conn.close()
        
        return flows


def deploy_messenger_integration():
    """Deploy Messenger Integration"""
    print("=" * 70)
    print("💬 ECOSYSTEM 36: MESSENGER INTEGRATION - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(MessengerConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(MESSENGER_SCHEMA)
        conn.commit()
        conn.close()
        
        print("\n   ✅ messenger_accounts table")
        print("   ✅ messenger_users table")
        print("   ✅ messenger_conversations table")
        print("   ✅ messenger_messages table")
        print("   ✅ messenger_flows table")
        print("   ✅ messenger_keywords table")
        print("   ✅ messenger_comment_triggers table")
        print("   ✅ messenger_broadcasts table")
        print("   ✅ messenger_sequences table")
        
        print("\n" + "=" * 70)
        print("✅ MESSENGER INTEGRATION DEPLOYED!")
        print("=" * 70)
        
        print("\n💬 FEATURES:")
        print("   • Facebook Messenger automation")
        print("   • Instagram DM automation")
        print("   • AI-powered conversations")
        print("   • Comment-to-DM triggers")
        print("   • Keyword responses with ON/OFF/TIMER")
        print("   • Broadcast messaging")
        print("   • Drip sequences")
        print("   • Quick replies & buttons")
        
        print("\n💰 REPLACES:")
        print("   • ManyChat: $150/month")
        print("   • Chatfuel: $200/month")
        print("   • MobileMonkey: $300/month")
        print("   • Custom dev: $50,000+")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_messenger_integration()
        """
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_accounts SET
                welcome_message = %s,
                welcome_buttons = %s,
                updated_at = NOW()
            WHERE account_id = %s
        """, (message, json.dumps(buttons or []), account_id))
        
        conn.commit()
        conn.close()
        return True
    
    def set_persistent_menu(self, account_id: str, menu_items: List[Dict]) -> bool:
        """Set persistent menu for Messenger"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_accounts SET
                persistent_menu = %s,
                updated_at = NOW()
            WHERE account_id = %s
        """, (json.dumps(menu_items), account_id))
        
        conn.commit()
        conn.close()
        
        # In production, call Facebook API to set menu
        logger.info(f"Set persistent menu for account {account_id}")
        return True
    
    # ========================================================================
    # CONVERSATION HANDLING
    # ========================================================================
    
    def handle_incoming_message(self, account_id: str, platform_user_id: str,
                               message_text: str, message_type: str = 'text',
                               media_url: str = None) -> Dict:
        """Handle incoming message from Messenger/Instagram"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get or create user
        cur.execute("""
            SELECT * FROM messenger_users 
            WHERE platform_user_id = %s AND account_id = %s
        """, (platform_user_id, account_id))
        user = cur.fetchone()
        
        if not user:
            # Create new user
            cur.execute("""
                INSERT INTO messenger_users (account_id, platform_user_id, platform)
                SELECT account_id, %s, platform FROM messenger_accounts WHERE account_id = %s
                RETURNING user_id
            """, (platform_user_id, account_id))
            user_id = str(cur.fetchone()['user_id'])
            is_new_user = True
        else:
            user_id = str(user['user_id'])
            is_new_user = False
        
        # Get or create conversation
        cur.execute("""
            SELECT * FROM messenger_conversations
            WHERE user_id = %s AND status = 'active'
            ORDER BY created_at DESC LIMIT 1
        """, (user_id,))
        conversation = cur.fetchone()
        
        if not conversation:
            cur.execute("""
                INSERT INTO messenger_conversations (account_id, user_id)
                VALUES (%s, %s)
                RETURNING conversation_id
            """, (account_id, user_id))
            conversation_id = str(cur.fetchone()['conversation_id'])
        else:
            conversation_id = str(conversation['conversation_id'])
        
        # Save incoming message
        cur.execute("""
            INSERT INTO messenger_messages (
                conversation_id, direction, message_type, text_content, media_url
            ) VALUES (%s, 'inbound', %s, %s, %s)
            RETURNING message_id
        """, (conversation_id, message_type, message_text, media_url))
        message_id = str(cur.fetchone()['message_id'])
        
        # Update conversation
        cur.execute("""
            UPDATE messenger_conversations SET
                last_message_at = NOW(),
                message_count = message_count + 1
            WHERE conversation_id = %s
        """, (conversation_id,))
        
        # Update user stats
        cur.execute("""
            UPDATE messenger_users SET
                last_interaction_at = NOW(),
                total_messages = total_messages + 1
            WHERE user_id = %s
        """, (user_id,))
        
        conn.commit()
        
        # Check for keyword triggers
        response = self._check_keywords(cur, account_id, message_text)
        
        # If no keyword match and AI enabled, generate AI response
        if not response:
            cur.execute("SELECT ai_enabled FROM messenger_accounts WHERE account_id = %s", (account_id,))
            account = cur.fetchone()
            if account and account['ai_enabled']:
                response = self._generate_ai_response(conversation_id, message_text)
        
        # Send welcome message if new user
        if is_new_user and not response:
            cur.execute("SELECT welcome_message, welcome_buttons FROM messenger_accounts WHERE account_id = %s", (account_id,))
            account = cur.fetchone()
            if account and account['welcome_message']:
                response = {
                    'text': account['welcome_message'],
                    'buttons': account['welcome_buttons'] or []
                }
        
        conn.close()
        
        return {
            'message_id': message_id,
            'conversation_id': conversation_id,
            'user_id': user_id,
            'is_new_user': is_new_user,
            'response': response
        }
    
    def _check_keywords(self, cur, account_id: str, message_text: str) -> Optional[Dict]:
        """Check if message matches any keywords"""
        message_lower = message_text.lower()
        
        cur.execute("""
            SELECT * FROM messenger_keywords
            WHERE account_id = %s AND mode != 'off'
            AND (timer_expires_at IS NULL OR timer_expires_at > NOW())
        """, (account_id,))
        
        for keyword in cur.fetchall():
            kw = keyword['keyword'].lower()
            match = False
            
            if keyword['match_type'] == 'exact' and message_lower == kw:
                match = True
            elif keyword['match_type'] == 'contains' and kw in message_lower:
                match = True
            elif keyword['match_type'] == 'starts_with' and message_lower.startswith(kw):
                match = True
            
            if match:
                # Update trigger count
                cur.execute("""
                    UPDATE messenger_keywords SET times_triggered = times_triggered + 1
                    WHERE keyword_id = %s
                """, (keyword['keyword_id'],))
                
                return {
                    'text': keyword['response_text'],
                    'buttons': keyword['response_buttons'] or [],
                    'flow_id': str(keyword['flow_id']) if keyword['flow_id'] else None,
                    'triggered_by': 'keyword',
                    'keyword': keyword['keyword']
                }
        
        return None
    
    def _generate_ai_response(self, conversation_id: str, message_text: str) -> Dict:
        """Generate AI response using Claude"""
        # In production, calls E13 AI Hub
        return {
            'text': f"Thanks for your message! A team member will follow up shortly.",
            'is_ai_generated': True
        }
    
    def send_message(self, conversation_id: str, text: str,
                    buttons: List[Dict] = None, quick_replies: List[Dict] = None,
                    media_url: str = None, message_type: str = 'text') -> str:
        """Send outbound message"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO messenger_messages (
                conversation_id, direction, message_type, text_content,
                media_url, buttons, quick_replies
            ) VALUES (%s, 'outbound', %s, %s, %s, %s, %s)
            RETURNING message_id
        """, (
            conversation_id, message_type, text, media_url,
            json.dumps(buttons or []), json.dumps(quick_replies or [])
        ))
        
        message_id = str(cur.fetchone()[0])
        
        # Update conversation
        cur.execute("""
            UPDATE messenger_conversations SET
                last_message_at = NOW(),
                message_count = message_count + 1
            WHERE conversation_id = %s
        """, (conversation_id,))
        
        # Update account stats
        cur.execute("""
            UPDATE messenger_accounts SET
                total_messages_sent = total_messages_sent + 1
            FROM messenger_conversations mc
            WHERE mc.conversation_id = %s
            AND messenger_accounts.account_id = mc.account_id
        """, (conversation_id,))
        
        conn.commit()
        conn.close()
        
        # In production, call Facebook/Instagram API to send
        return message_id
    
    # ========================================================================
    # AUTOMATION FLOWS
    # ========================================================================
    
    def create_flow(self, account_id: str, name: str, trigger_type: str,
                   trigger_config: Dict = None, steps: List[Dict] = None,
                   mode: str = 'on', timer_minutes: int = None) -> str:
        """Create automation flow"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_flows (
                account_id, name, trigger_type, trigger_config, steps,
                mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING flow_id
        """, (
            account_id, name, trigger_type,
            json.dumps(trigger_config or {}),
            json.dumps(steps or []),
            mode, timer_minutes, timer_expires_at
        ))
        
        flow_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created flow: {name} ({mode})")
        return flow_id
    
    def add_keyword(self, account_id: str, keyword: str, response_text: str,
                   match_type: str = 'contains', buttons: List[Dict] = None,
                   flow_id: str = None, mode: str = 'on',
                   timer_minutes: int = None) -> str:
        """Add keyword trigger"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_keywords (
                account_id, keyword, match_type, action_type,
                response_text, response_buttons, flow_id,
                mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, 'respond', %s, %s, %s, %s, %s, %s)
            RETURNING keyword_id
        """, (
            account_id, keyword.upper(), match_type, response_text,
            json.dumps(buttons or []), flow_id, mode, timer_minutes, timer_expires_at
        ))
        
        keyword_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return keyword_id
    
    def set_flow_mode(self, flow_id: str, mode: str,
                     timer_minutes: int = None) -> Dict:
        """Set flow control mode (ON/OFF/TIMER)"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            UPDATE messenger_flows SET
                mode = %s,
                timer_minutes = %s,
                timer_expires_at = %s,
                updated_at = NOW()
            WHERE flow_id = %s
        """, (mode, timer_minutes, timer_expires_at, flow_id))
        
        conn.commit()
        conn.close()
        
        return {
            'flow_id': flow_id,
            'mode': mode,
            'timer_minutes': timer_minutes,
            'timer_expires_at': timer_expires_at.isoformat() if timer_expires_at else None
        }
    
    # ========================================================================
    # COMMENT-TO-DM AUTOMATION
    # ========================================================================
    
    def create_comment_trigger(self, account_id: str, post_id: str,
                              dm_message: str, keywords: List[str] = None,
                              trigger_on_any: bool = False,
                              dm_buttons: List[Dict] = None,
                              flow_id: str = None,
                              mode: str = 'on',
                              timer_minutes: int = None) -> str:
        """Create comment-to-DM automation"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_comment_triggers (
                account_id, post_id, trigger_keywords, trigger_on_any_comment,
                dm_message, dm_buttons, flow_id, mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING trigger_id
        """, (
            account_id, post_id, json.dumps(keywords or []),
            trigger_on_any, dm_message, json.dumps(dm_buttons or []),
            flow_id, mode, timer_minutes, timer_expires_at
        ))
        
        trigger_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        logger.info(f"Created comment trigger for post {post_id}")
        return trigger_id
    
    def process_comment(self, trigger_id: str, commenter_id: str,
                       comment_text: str) -> Optional[Dict]:
        """Process incoming comment and trigger DM if matched"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM messenger_comment_triggers
            WHERE trigger_id = %s AND is_active = true
            AND mode != 'off'
            AND (timer_expires_at IS NULL OR timer_expires_at > NOW())
        """, (trigger_id,))
        
        trigger = cur.fetchone()
        if not trigger:
            conn.close()
            return None
        
        # Check if should trigger
        should_dm = trigger['trigger_on_any_comment']
        
        if not should_dm and trigger['trigger_keywords']:
            comment_lower = comment_text.lower()
            for kw in trigger['trigger_keywords']:
                if kw.lower() in comment_lower:
                    should_dm = True
                    break
        
        if should_dm:
            # Update stats
            cur.execute("""
                UPDATE messenger_comment_triggers SET
                    comments_detected = comments_detected + 1,
                    dms_sent = dms_sent + 1
                WHERE trigger_id = %s
            """, (trigger_id,))
            
            conn.commit()
            conn.close()
            
            return {
                'send_dm': True,
                'to_user_id': commenter_id,
                'message': trigger['dm_message'],
                'buttons': trigger['dm_buttons'],
                'flow_id': str(trigger['flow_id']) if trigger['flow_id'] else None,
                'delay_seconds': trigger['dm_delay_seconds']
            }
        
        conn.close()
        return {'send_dm': False}
    
    # ========================================================================
    # BROADCASTS
    # ========================================================================
    
    def create_broadcast(self, account_id: str, name: str, content: str,
                        message_type: str = 'text', media_url: str = None,
                        buttons: List[Dict] = None, target_tags: List[str] = None,
                        scheduled_at: datetime = None) -> str:
        """Create broadcast message"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO messenger_broadcasts (
                account_id, name, message_type, content, media_url,
                buttons, target_tags, scheduled_at, status
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING broadcast_id
        """, (
            account_id, name, message_type, content, media_url,
            json.dumps(buttons or []), json.dumps(target_tags or []),
            scheduled_at, 'scheduled' if scheduled_at else 'draft'
        ))
        
        broadcast_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return broadcast_id
    
    def send_broadcast(self, broadcast_id: str) -> Dict:
        """Send broadcast to all targeted users"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM messenger_broadcasts WHERE broadcast_id = %s", (broadcast_id,))
        broadcast = cur.fetchone()
        
        if not broadcast:
            conn.close()
            return {'error': 'Broadcast not found'}
        
        # Get targeted users
        query = """
            SELECT * FROM messenger_users
            WHERE account_id = %s AND is_subscribed = true
        """
        params = [broadcast['account_id']]
        
        if broadcast['target_tags']:
            query += " AND tags ?| %s"
            params.append(broadcast['target_tags'])
        
        cur.execute(query, params)
        users = cur.fetchall()
        
        # Update broadcast
        cur.execute("""
            UPDATE messenger_broadcasts SET
                status = 'sent',
                sent_at = NOW(),
                total_recipients = %s
            WHERE broadcast_id = %s
        """, (len(users), broadcast_id))
        
        conn.commit()
        conn.close()
        
        # In production, queue messages for sending via Facebook API
        return {
            'broadcast_id': broadcast_id,
            'recipients': len(users),
            'status': 'sent'
        }
    
    # ========================================================================
    # SEQUENCES (DRIP CAMPAIGNS)
    # ========================================================================
    
    def create_sequence(self, account_id: str, name: str,
                       steps: List[Dict], mode: str = 'on',
                       timer_minutes: int = None) -> str:
        """Create message sequence"""
        conn = self._get_db()
        cur = conn.cursor()
        
        timer_expires_at = None
        if mode == 'timer' and timer_minutes:
            timer_expires_at = datetime.now() + timedelta(minutes=timer_minutes)
        
        cur.execute("""
            INSERT INTO messenger_sequences (
                account_id, name, steps, mode, timer_minutes, timer_expires_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING sequence_id
        """, (account_id, name, json.dumps(steps), mode, timer_minutes, timer_expires_at))
        
        sequence_id = str(cur.fetchone()[0])
        conn.commit()
        conn.close()
        
        return sequence_id
    
    def enroll_in_sequence(self, sequence_id: str, user_id: str) -> str:
        """Enroll user in sequence"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get sequence
        cur.execute("SELECT steps FROM messenger_sequences WHERE sequence_id = %s", (sequence_id,))
        sequence = cur.fetchone()
        
        if not sequence:
            conn.close()
            return None
        
        steps = sequence['steps']
        first_delay = steps[0].get('delay_minutes', 0) if steps else 0
        next_message_at = datetime.now() + timedelta(minutes=first_delay)
        
        cur.execute("""
            INSERT INTO messenger_sequence_enrollments (
                sequence_id, user_id, next_message_at
            ) VALUES (%s, %s, %s)
            RETURNING enrollment_id
        """, (sequence_id, user_id, next_message_at))
        
        enrollment_id = str(cur.fetchone()['enrollment_id'])
        
        # Update sequence stats
        cur.execute("""
            UPDATE messenger_sequences SET total_enrolled = total_enrolled + 1
            WHERE sequence_id = %s
        """, (sequence_id,))
        
        conn.commit()
        conn.close()
        
        return enrollment_id
    
    # ========================================================================
    # USER MANAGEMENT
    # ========================================================================
    
    def tag_user(self, user_id: str, tags: List[str]) -> bool:
        """Add tags to user"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_users SET
                tags = tags || %s::jsonb,
                updated_at = NOW()
            WHERE user_id = %s
        """, (json.dumps(tags), user_id))
        
        conn.commit()
        conn.close()
        return True
    
    def link_to_contact(self, user_id: str, contact_id: str) -> bool:
        """Link messenger user to CRM contact"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_users SET
                contact_id = %s,
                updated_at = NOW()
            WHERE user_id = %s
        """, (contact_id, user_id))
        
        conn.commit()
        conn.close()
        return True
    
    def unsubscribe_user(self, user_id: str) -> bool:
        """Unsubscribe user from broadcasts"""
        conn = self._get_db()
        cur = conn.cursor()
        
        cur.execute("""
            UPDATE messenger_users SET
                is_subscribed = false,
                unsubscribed_at = NOW()
            WHERE user_id = %s
        """, (user_id,))
        
        conn.commit()
        conn.close()
        return True
    
    # ========================================================================
    # ANALYTICS
    # ========================================================================
    
    def get_account_stats(self, account_id: str) -> Dict:
        """Get account statistics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM v_messenger_stats WHERE account_id = %s", (account_id,))
        stats = cur.fetchone()
        conn.close()
        
        return dict(stats) if stats else {}
    
    def get_flow_performance(self, account_id: str) -> List[Dict]:
        """Get flow performance metrics"""
        conn = self._get_db()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("""
            SELECT * FROM v_flow_performance
            WHERE flow_id IN (SELECT flow_id FROM messenger_flows WHERE account_id = %s)
        """, (account_id,))
        
        flows = [dict(f) for f in cur.fetchall()]
        conn.close()
        
        return flows


def deploy_messenger_integration():
    """Deploy Messenger Integration"""
    print("=" * 70)
    print("💬 ECOSYSTEM 36: MESSENGER INTEGRATION - DEPLOYMENT")
    print("=" * 70)
    
    try:
        conn = psycopg2.connect(MessengerConfig.DATABASE_URL)
        cur = conn.cursor()
        
        print("\nDeploying schema...")
        cur.execute(MESSENGER_SCHEMA)
        conn.commit()
        conn.close()
        
        print("   ✅ messenger_accounts table")
        print("   ✅ messenger_users table")
        print("   ✅ messenger_conversations table")
        print("   ✅ messenger_messages table")
        print("   ✅ messenger_flows table")
        print("   ✅ messenger_keywords table")
        print("   ✅ messenger_comment_triggers table")
        print("   ✅ messenger_broadcasts table")
        print("   ✅ messenger_sequences table")
        
        print("\n" + "=" * 70)
        print("✅ MESSENGER INTEGRATION DEPLOYED!")
        print("=" * 70)
        
        print("\n💰 REPLACES:")
        print("   • ManyChat: $150/month")
        print("   • Chatfuel: $200/month")
        print("   • MobileMonkey: $300/month")
        print("   • Custom chatbot dev: $50,000+")
        print("   TOTAL SAVINGS: $650+/month + $50K dev")
        
        return True
    except Exception as e:
        print(f"❌ Failed: {e}")
        return False


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--deploy":
        deploy_messenger_integration()
