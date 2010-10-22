module Neo4j
  module Index
    class IndexerRegistry #:nodoc:
      class << self

        def clear_all_indexes
          @@indexers.values.each {|i| i.clear_index_type}
        end

        def create_for(this_clazz, using_other_clazz, type)
          @@indexers ||= {}
          @@indexers[this_clazz.to_s] = @@indexers[using_other_clazz.to_s] || Indexer.new(this_clazz, type)
          @@indexers[this_clazz.to_s]
        end

        def find_by_class(classname)
          @@indexers[classname]
        end

        def on_node_deleted(node, old_props, tx_data)
          indexer = find_by_class(old_props['_classname'] || node.class.to_s)
          indexer && indexer.remove_index_on_fields(node, old_props, tx_data)
        end

        def on_property_changed(node, field, old_val, new_val)
          classname = node['_classname'] || node.class.to_s
          indexer = find_by_class(classname)
          indexer && indexer.update_index_on(node, field, old_val, new_val)
        end

        def on_rel_property_changed(rel, field, old_val, new_val)
          # works exactly like for nodes
          on_property_changed(rel, field, old_val, new_val)
        end

        def on_relationship_created(rel, tx_data)
          end_node = rel._end_node
          # if end_node was created in this transaction then it will be handled in on_property_changed
          created = tx_data.created_nodes.find{|n| n.neo_id == end_node.neo_id}
          unless created
            indexer = find_by_class(end_node['_classname'])
            indexer && indexer.update_on_new_relationship(rel)
          end
        end

        def on_relationship_deleted(rel, old_props, tx_data)
          on_node_deleted(rel, old_props, tx_data)
          # if only the relationship has been deleted then we have to remove the index
          # if both the relationship and the node has been deleted then the index will be removed in the
          # on_node_deleted callback
          end_node = rel._end_node
          deleted = tx_data.deleted_nodes.find{|n| n.neo_id == end_node.neo_id}
          unless deleted
            indexer = find_by_class(end_node['_classname'])
            indexer && indexer.update_on_deleted_relationship(rel)
          end
        end

        def on_neo4j_shutdown(*)
          @@indexers.each_value {|indexer| indexer.on_neo4j_shutdown}
        end
      end
    end
    Neo4j.unstarted_db.event_handler.add(IndexerRegistry)

  end
end
