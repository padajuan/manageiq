describe "MiqSchedule Filter" do
  context "Getting schedule targets" do
    before(:each) do
      @server1 = EvmSpecHelper.local_miq_server

      # Vm Scan Schedules
      @vm1 = FactoryGirl.create(:vm_vmware, :name => "Test VM 1")
      @vm2 = FactoryGirl.create(:vm_vmware, :name => "Test VM 2")
      @vm3 = FactoryGirl.create(:vm_vmware, :name => "Test VM 3")
      @vm4 = FactoryGirl.create(:vm_vmware, :name => "Special Test VM")

      @vm_single_schedule = FactoryGirl.create(:miq_schedule,
                                               :towhat       => "Vm",
                                               :sched_action => {:method => "vm_scan"},
                                               :filter       => MiqExpression.new("=" => {"field" => "Vm-name", "value" => "Special Test VM"})
                                              )

      @vm_all_schedule = FactoryGirl.create(:miq_schedule,
                                            :towhat       => "Vm",
                                            :sched_action => {:method => "vm_scan"},
                                            :filter       => MiqExpression.new("IS NOT NULL" => {"field" => "Vm-name"})
                                           )

      # Schedule froma saved search
      @search = FactoryGirl.create(:miq_search,
                                   :db     => "Vm",
                                   :filter => MiqExpression.new("=" => {"field" => "Vm-name", "value" => "Test VM 2"})
                                  )
      @vm_search_schedule = FactoryGirl.create(:miq_schedule,
                                               :towhat        => "Vm",
                                               :sched_action  => {:method => "vm_scan"},
                                               :miq_search_id => @search.id
                                              )

      # DB Baskup Schedule
      @db_backup = FactoryGirl.create(:miq_schedule,
                                      :towhat       => "DatabaseBackup",
                                      :sched_action => {:method => "db_backup"}
                                     )
    end

    context "for a scheduled report" do
      before(:each) do
        MiqReport.seed_report("Vendor and Guest OS")
        @report = MiqReport.first
        @report_schedule = FactoryGirl.create(:miq_schedule,
                                              :towhat       => "MiqReport",
                                              :sched_action => {:method => "run_report"},
                                              :filter       => MiqExpression.new("=" => {"field" => "MiqReport-id", "value" => @report.id})
                                             )
      end

      it "should get the correct report" do
        targets = @report_schedule.get_targets
        expect(targets.length).to eq(1)
        expect(targets.first.name).to eq(@report.name)
      end
    end

    it "should get the correct target VM from a schedule to scan a single VM" do
      targets = @vm_single_schedule.get_targets
      expect(targets.length).to eq(1)
      expect(targets.first.name).to eq("Special Test VM")
    end

    it "should queue a scan job for target VM from a schedule to scan a single VM" do
      MiqSchedule.queue_scheduled_work(@vm_single_schedule.id, 0, Time.now.utc, {})
      msg = MiqQueue.first
      msg.deliver
      msg.destroy

      msgs = MiqQueue.all
      expect(msgs.length).to eq(1)

      msg = msgs.first
      expect(msg.class_name).to eq(@vm4.class.base_class.name)
      expect(msg.method_name).to eq("scan")
      expect(msg.instance_id).to eq(@vm4.id)
    end

    it "should get the correct target VM from a schedule to scan all VMs" do
      targets = @vm_all_schedule.get_targets
      expect(targets.length).to eq(4)
    end

    it "should get the correct target VM from a schedule based on a saved search" do
      targets = @vm_search_schedule.get_targets
      expect(targets.length).to eq(1)
      expect(targets.first.name).to eq("Test VM 2")
    end

    it "should get the the DatabaseBackup class for a scheduled DB Backup" do
      targets = @db_backup.get_targets
      expect(targets.length).to eq(1)
      expect(targets.first.name).to eq("DatabaseBackup")
    end
  end
end
